import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    var onInstallCertificate: (() async throws -> Void)?

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
                .tag(0)

            DomainListView()
                .tabItem { Label("HTTPS Domains", systemImage: "lock.shield") }
                .tag(1)

            CertificateSetupView(onInstall: onInstallCertificate)
                .tabItem { Label("Certificate", systemImage: "certificate") }
                .tag(2)
        }
        .frame(width: 540, height: 380)
    }
}

// MARK: - General Settings

private struct GeneralSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        @Bindable var store = settingsStore

        Form {
            Section("Proxy") {
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("8080", value: $store.settings.port, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                Toggle("Start proxy automatically on launch", isOn: $store.settings.autoStartProxy)
            }

            Section("Capture") {
                Toggle("Record traffic", isOn: $store.settings.isRecording)

                HStack {
                    Text("Max stored requests")
                    Spacer()
                    TextField("10000", value: $store.settings.maxExchanges, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                HStack {
                    Text("Connection timeout (seconds)")
                    Spacer()
                    TextField("30", value: $store.settings.connectionTimeoutSeconds, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: settingsStore.settings) { _, _ in
            settingsStore.save()
        }
        .padding()
    }
}
