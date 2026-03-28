import Foundation
import Crypto
import X509
import SwiftASN1
import NIOSSL

/// Manages the root CA certificate and signs per-domain leaf certificates for HTTPS MITM.
///
/// On first launch the CA is generated and persisted in Application Support.
/// On subsequent launches the existing CA is loaded from disk.
final class CertificateAuthority: Sendable {

    // MARK: - Types

    enum CAError: Error, LocalizedError {
        case storageDirCreationFailed
        case missingCAFiles
        case keyDeserializationFailed

        var errorDescription: String? {
            switch self {
            case .storageDirCreationFailed: return "Cannot create Application Support directory for RoxProxy."
            case .missingCAFiles: return "CA files are missing or corrupted."
            case .keyDeserializationFailed: return "Cannot load CA private key from disk."
            }
        }
    }

    // MARK: - Storage paths

    private static var storageDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("RoxProxy")
    }

    private static var certURL: URL { storageDir.appendingPathComponent("ca-cert.der") }
    private static var keyURL: URL  { storageDir.appendingPathComponent("ca-key.pem") }

    // MARK: - Internal state

    let caCertificate: Certificate
    let caPrivateKey: Certificate.PrivateKey
    /// The raw DER bytes as written/read from disk — stable across serialization round-trips.
    private let _caDERBytes: Data

    // MARK: - Init / factory

    /// Load an existing CA from disk or generate a new one.
    static func loadOrGenerate() throws -> CertificateAuthority {
        let dir = storageDir
        let certURL = Self.certURL
        let keyURL  = Self.keyURL

        // Ensure storage directory exists
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                throw CAError.storageDirCreationFailed
            }
        }

        if FileManager.default.fileExists(atPath: certURL.path),
           FileManager.default.fileExists(atPath: keyURL.path) {
            return try loadFromDisk(certURL: certURL, keyURL: keyURL)
        } else {
            return try generateAndSave(certURL: certURL, keyURL: keyURL)
        }
    }

    private init(certificate: Certificate, privateKey: Certificate.PrivateKey, derBytes: Data) {
        self.caCertificate = certificate
        self.caPrivateKey  = privateKey
        self._caDERBytes   = derBytes
    }

    // MARK: - Load from disk

    private static func loadFromDisk(certURL: URL, keyURL: URL) throws -> CertificateAuthority {
        let certDER = try Data(contentsOf: certURL)
        let keyPEM  = try String(contentsOf: keyURL, encoding: .utf8)

        let cert = try Certificate(derEncoded: Array(certDER))
        let key  = try Certificate.PrivateKey(pemEncoded: keyPEM)

        return CertificateAuthority(certificate: cert, privateKey: key, derBytes: certDER)
    }

    // MARK: - Generate

    private static func generateAndSave(certURL: URL, keyURL: URL) throws -> CertificateAuthority {
        // 1. Generate P-256 key pair
        let rawKey = P256.Signing.PrivateKey()
        let privateKey = Certificate.PrivateKey(rawKey)
        let publicKey  = Certificate.PublicKey(rawKey.publicKey)

        // 2. Build distinguished name
        let name = try DistinguishedName {
            CommonName("Rox Proxy CA")
            OrganizationName("Rox Proxy")
        }

        // 3. Validity: 10 years
        let now = Date()
        let expiry = Calendar.current.date(byAdding: .year, value: 10, to: now)!

        // 4. Extensions for a CA cert
        let extensions = try Certificate.Extensions {
            Critical(BasicConstraints.isCertificateAuthority(maxPathLength: nil))
            Critical(KeyUsage(keyCertSign: true, cRLSign: true))
        }

        // 5. Create self-signed certificate
        let cert = try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: publicKey,
            notValidBefore: now,
            notValidAfter: expiry,
            issuer: name,
            subject: name,
            extensions: extensions,
            issuerPrivateKey: privateKey
        )

        // 6. Persist to disk
        let certPEMDoc = try cert.serializeAsPEM()
        let keyPEM     = try privateKey.serializeAsPEM().pemString

        try Data(certPEMDoc.derBytes).write(to: certURL, options: .atomic)
        try keyPEM.write(to: keyURL, atomically: true, encoding: .utf8)

        // Protect the private key file (owner read-only)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)

        return CertificateAuthority(certificate: cert, privateKey: privateKey, derBytes: Data(certPEMDoc.derBytes))
    }

    // MARK: - Public API

    /// Returns the CA certificate as DER bytes (for Keychain installation and export).
    /// These are the exact bytes stored on disk — stable across serialization round-trips.
    func caCertificateDER() -> Data {
        _caDERBytes
    }

    /// Creates and returns a leaf certificate for the given hostname signed by this CA.
    /// The returned pair is ready for use in a `NIOSSLServerHandler`.
    func generateDomainCertificate(for host: String) throws -> (NIOSSLCertificate, NIOSSLPrivateKey) {
        // Generate fresh key for this domain
        let rawLeafKey = P256.Signing.PrivateKey()
        let leafPrivateKey = Certificate.PrivateKey(rawLeafKey)
        let leafPublicKey  = Certificate.PublicKey(rawLeafKey.publicKey)

        let subjectName = try DistinguishedName {
            CommonName(host)
            OrganizationName("Rox Proxy")
        }

        // Backdate notBefore by 1 hour to tolerate clock skew between the Mac
        // and the intercepted device (Chrome on Android rejects certs where
        // notBefore is even slightly in the future).
        let now    = Date()
        let start  = now.addingTimeInterval(-3600)
        let expiry = Calendar.current.date(byAdding: .year, value: 1, to: now)!

        let extensions = try Certificate.Extensions {
            Critical(
                SubjectAlternativeNames([.dnsName(host)])
            )
            KeyUsage(digitalSignature: true)
            try ExtendedKeyUsage([.serverAuth])
        }

        let leafCert = try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: leafPublicKey,
            notValidBefore: start,
            notValidAfter: expiry,
            issuer: caCertificate.subject,
            subject: subjectName,
            extensions: extensions,
            issuerPrivateKey: caPrivateKey
        )

        // Serialize to PEM (NIOSSLCertificate accepts PEM bytes)
        let certPEM = try leafCert.serializeAsPEM().pemString
        let keyPEM  = try leafPrivateKey.serializeAsPEM().pemString

        let nioSSLCert = try NIOSSLCertificate(bytes: Array(certPEM.utf8), format: .pem)
        let nioSSLKey  = try NIOSSLPrivateKey(bytes: Array(keyPEM.utf8), format: .pem)

        return (nioSSLCert, nioSSLKey)
    }
}
