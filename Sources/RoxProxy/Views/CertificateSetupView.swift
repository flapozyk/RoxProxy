import SwiftUI

struct CertificateSetupView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var isInstalling = false
    @State private var installError: String?

    /// Injected at the call site from AppDelegate — needed to access CA + KeychainInstaller.
    var onInstall: (() async throws -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // CA trust status
            HStack(spacing: 8) {
                Image(systemName: settingsStore.isCATrusted
                      ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .foregroundStyle(settingsStore.isCATrusted ? .green : .orange)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(settingsStore.isCATrusted
                         ? "Certificate installed and trusted"
                         : "Certificate not yet trusted")
                        .fontWeight(.medium)
                    Text(settingsStore.isCATrusted
                         ? "HTTPS traffic can be decrypted for configured domains."
                         : "Install the CA certificate to enable HTTPS decryption.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(settingsStore.isCATrusted
                          ? Color.green.opacity(0.08)
                          : Color.orange.opacity(0.08))
            )

            if let err = installError {
                Label(err, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Button {
                    Task { await install() }
                } label: {
                    if isInstalling {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Text("Install CA Certificate…")
                    }
                }
                .disabled(isInstalling || settingsStore.isCATrusted || onInstall == nil)

                Spacer()
            }

            Text("Installing the certificate requires your admin password. It will be added to the System keychain as a trusted root.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    @MainActor
    private func install() async {
        guard let onInstall else { return }
        isInstalling = true
        installError = nil
        do {
            try await onInstall()
        } catch {
            installError = error.localizedDescription
        }
        isInstalling = false
    }
}
