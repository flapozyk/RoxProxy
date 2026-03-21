import Foundation
import Security

/// Installs and checks trust of the root CA certificate in the macOS Keychain.
///
/// Uses the `security` CLI tool which automatically triggers the macOS admin
/// authentication dialog — no manual `AuthorizationCreate` boilerplate needed.
final class KeychainInstaller {

    enum KeychainError: Error, LocalizedError {
        case writeTempFileFailed
        case installFailed(Int32, String)
        case removeTempFileFailed

        var errorDescription: String? {
            switch self {
            case .writeTempFileFailed:
                return "Cannot write CA certificate to a temporary file."
            case .installFailed(let code, let output):
                return "Keychain installation failed (exit \(code)): \(output)"
            case .removeTempFileFailed:
                return "Cannot remove the temporary CA certificate file."
            }
        }
    }

    // MARK: - Public API

    /// Installs the CA certificate as a trusted root in the System keychain.
    /// Triggers a macOS admin password prompt via the `security` CLI.
    func installCAInSystemKeychain(derData: Data) async throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rox-proxy-ca-\(UUID().uuidString).der")

        guard (try? derData.write(to: tempURL, options: .atomic)) != nil else {
            throw KeychainError.writeTempFileFailed
        }
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let (exitCode, output) = try await runSecurity([
            "add-trusted-cert",
            "-d",
            "-r", "trustRoot",
            "-k", "/Library/Keychains/System.keychain",
            tempURL.path
        ])

        guard exitCode == 0 else {
            throw KeychainError.installFailed(exitCode, output)
        }
    }

    /// Returns true only if the CA cert has explicit trust settings in the admin or
    /// system domain — i.e. it was installed as a trusted root via
    /// `security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain`.
    ///
    /// `SecItemCopyMatching` only checks existence in any keychain and would incorrectly
    /// return true for a cert that is present but NOT trusted as a root CA.
    func isCAInstalled(derData: Data) -> Bool {
        guard let secCert = SecCertificateCreateWithData(nil, derData as CFData) else {
            return false
        }
        var settings: CFArray?
        // .admin matches the `-d` flag used in installCAInSystemKeychain
        if SecTrustSettingsCopyTrustSettings(secCert, .admin, &settings) == errSecSuccess {
            return true
        }
        if SecTrustSettingsCopyTrustSettings(secCert, .system, &settings) == errSecSuccess {
            return true
        }
        return false
    }

    // MARK: - Private

    private func runSecurity(_ args: [String]) async throws -> (Int32, String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            process.arguments = args

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError  = pipe

            process.terminationHandler = { proc in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: (proc.terminationStatus, output))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
