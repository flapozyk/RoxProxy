import SwiftUI

struct RoxProxyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("Rox Proxy") {
            MainWindowView()
                .environment(appDelegate.sessionStore)
                .environment(appDelegate.settingsStore)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Rox Proxy") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
        }
        .defaultSize(width: 1100, height: 700)

        Settings {
            SettingsView(onInstallCertificate: { [weak appDelegate] in
                try await appDelegate?.installCertificate()
            })
            .environment(appDelegate.settingsStore)
        }
    }
}
