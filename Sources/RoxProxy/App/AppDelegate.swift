import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let sessionStore = ProxySessionStore()
    let settingsStore = SettingsStore()

    private(set) var certificateAuthority: CertificateAuthority?
    private(set) var domainCertCache: DomainCertificateCache?
    let keychainInstaller = KeychainInstaller()

    private var proxyServer: ProxyServer?
    private var systemProxyManager: SystemProxyManager?
    private var crashGuard: CrashGuard?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        settingsStore.load()
        crashGuard = CrashGuard()
        crashGuard?.installSignalHandlers()
        crashGuard?.recoverIfNeeded(settingsStore: settingsStore)

        // Load or generate the CA (done synchronously on launch; fast after first run)
        do {
            let ca = try CertificateAuthority.loadOrGenerate()
            certificateAuthority = ca
            domainCertCache = DomainCertificateCache(ca: ca)

            // Update CA trust status in settings store
            let derData = ca.caCertificateDER()
            settingsStore.isCATrusted = keychainInstaller.isCAInstalled(derData: derData)
        } catch {
            // Non-fatal: HTTPS MITM won't work, but HTTP proxy still will
            print("RoxProxy: CA initialization failed: \(error)")
        }

        // Observe start/stop notifications from the toolbar
        NotificationCenter.default.addObserver(
            forName: .startProxy, object: nil, queue: .main
        ) { [weak self] _ in self?.startProxy() }

        NotificationCenter.default.addObserver(
            forName: .stopProxy, object: nil, queue: .main
        ) { [weak self] _ in self?.stopProxy() }

        if settingsStore.settings.autoStartProxy {
            startProxy()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopProxy()
        crashGuard?.clearSentinel()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func startProxy() {
        let port = settingsStore.settings.port
        let server = ProxyServer(
            port: port,
            store: sessionStore,
            settingsStore: settingsStore,
            certificateAuthority: certificateAuthority,
            domainCertCache: domainCertCache
        )
        proxyServer = server

        Task {
            do {
                try await server.start()
                await MainActor.run {
                    sessionStore.proxyState = .running(port: port)
                }
                crashGuard?.writeSentinel(port: port)

                let sysProxy = SystemProxyManager()
                systemProxyManager = sysProxy
                try sysProxy.enableProxy(port: port)
            } catch {
                await MainActor.run {
                    sessionStore.proxyState = .error(error.localizedDescription)
                }
            }
        }
    }

    /// Installs the root CA certificate into the System keychain (requires admin).
    func installCertificate() async throws {
        guard let ca = certificateAuthority else {
            throw CertInstallError.caNotInitialized
        }
        let derData = ca.caCertificateDER()
        try await keychainInstaller.installCAInSystemKeychain(derData: derData)
        isCATrusted = keychainInstaller.isCAInstalled(derData: derData)
        settingsStore.isCATrusted = isCATrusted
    }

    private(set) var isCATrusted: Bool = false

    enum CertInstallError: Error, LocalizedError {
        case caNotInitialized
        var errorDescription: String? { "Certificate Authority not initialized." }
    }

    func stopProxy() {
        systemProxyManager?.disableProxy()
        systemProxyManager = nil
        crashGuard?.clearSentinel()

        let server = proxyServer
        proxyServer = nil
        Task {
            try? await server?.stop()
        }

        Task { @MainActor in
            sessionStore.proxyState = .stopped
        }
    }
}
