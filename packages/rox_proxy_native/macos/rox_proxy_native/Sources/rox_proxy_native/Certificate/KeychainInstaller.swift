import Foundation
import Security

/// Installs and checks trust of the root CA certificate in the macOS Keychain.
///
/// Uses the Security Framework APIs directly (not a subprocess) so that macOS
/// can show the standard authorization dialog — including Touch ID — from the
/// app's own window server session.
final class KeychainInstaller {

    enum KeychainError: Error, LocalizedError {
        case invalidCertificateData
        case addToKeychainFailed(OSStatus, String)
        case trustSettingsFailed(OSStatus, String)

        var errorDescription: String? {
            switch self {
            case .invalidCertificateData:
                return "Cannot parse certificate data."
            case .addToKeychainFailed(let code, let msg):
                return "Failed to add certificate to keychain (\(code)): \(msg)"
            case .trustSettingsFailed(let code, let msg):
                return "Failed to set trust settings (\(code)): \(msg)"
            }
        }
    }

    // MARK: - Public API

    /// Adds the CA certificate to the user's login keychain and marks it as a
    /// trusted root CA in the user trust domain.
    ///
    /// - Calling this from the main process (not a subprocess) allows macOS to
    ///   show the Trust confirmation dialog, which supports Touch ID on Macs
    ///   that have it enrolled.
    /// - User-domain trust is sufficient for all HTTPS traffic by the current user.
    func installCAInSystemKeychain(derData: Data) async throws {
        guard let secCert = SecCertificateCreateWithData(nil, derData as CFData) else {
            throw KeychainError.invalidCertificateData
        }

        // Step 1 — add to the login keychain (idempotent: duplicate is fine)
        let addQuery: [CFString: Any] = [
            kSecClass:    kSecClassCertificate,
            kSecValueRef: secCert,
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
            let msg = SecCopyErrorMessageString(addStatus, nil) as String? ?? "unknown"
            throw KeychainError.addToKeychainFailed(addStatus, msg)
        }

        // Step 2 — set user-domain trust as root CA.
        // macOS automatically shows a confirmation dialog (with Touch ID support)
        // because this is called from the app process, which has a UI session.
        //
        // kSecTrustSettingsResultTrustRoot = 1 (SecTrustSettings.h)
        let trustEntry: NSDictionary = [kSecTrustSettingsResult: NSNumber(value: UInt32(1))]
        let settings: NSArray = [trustEntry]
        let trustStatus = SecTrustSettingsSetTrustSettings(secCert, .user, settings)
        guard trustStatus == errSecSuccess else {
            let msg = SecCopyErrorMessageString(trustStatus, nil) as String? ?? "unknown"
            throw KeychainError.trustSettingsFailed(trustStatus, msg)
        }
    }

    /// Returns true if the CA cert has explicit trust settings in any domain
    /// (user, admin, or system).
    func isCAInstalled(derData: Data) -> Bool {
        guard let secCert = SecCertificateCreateWithData(nil, derData as CFData) else {
            return false
        }
        var settings: CFArray?
        return SecTrustSettingsCopyTrustSettings(secCert, .user,   &settings) == errSecSuccess
            || SecTrustSettingsCopyTrustSettings(secCert, .admin,  &settings) == errSecSuccess
            || SecTrustSettingsCopyTrustSettings(secCert, .system, &settings) == errSecSuccess
    }
}
