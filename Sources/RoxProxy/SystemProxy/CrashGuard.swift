import AppKit
import Foundation

/// Detects unclean shutdowns (crashes) and ensures the system proxy is
/// restored when the app restarts.
///
/// **Lifecycle:**
/// 1. On launch, `recoverIfNeeded()` checks for a sentinel file left by a
///    previous crash and disables any lingering proxy settings.
/// 2. When the proxy starts, `writeSentinel(port:)` creates the file.
/// 3. On clean shutdown (`applicationWillTerminate`), `clearSentinel()` removes it.
/// 4. `installSignalHandlers()` installs SIGTERM/SIGINT handlers that attempt
///    a clean exit so `applicationWillTerminate` is called.
final class CrashGuard {

    // MARK: - Paths

    private var sentinelURL: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("RoxProxy/.proxy-active")
    }

    private static var staticSentinelPath: String = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("RoxProxy/.proxy-active").path
    }()

    // MARK: - Crash recovery

    /// Call on launch.  If a sentinel file is found, a previous run crashed with
    /// the proxy active — disable it now and remove the file.
    func recoverIfNeeded(settingsStore: SettingsStore) {
        guard FileManager.default.fileExists(atPath: sentinelURL.path) else { return }

        // Attempt to restore proxy on all services (we don't know which were set)
        SystemProxyManager.forceDisableOnAllServices()
        clearSentinel()
    }

    // MARK: - Sentinel file

    func writeSentinel(port: Int) {
        let dir = sentinelURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = "\(port)".data(using: .utf8)
        FileManager.default.createFile(atPath: sentinelURL.path, contents: data)
    }

    func clearSentinel() {
        try? FileManager.default.removeItem(at: sentinelURL)
    }

    // MARK: - Signal handlers

    /// Installs SIGTERM and SIGINT handlers that convert the signal into a
    /// graceful `NSApplication.terminate(_:)` call so `applicationWillTerminate`
    /// (and therefore proxy cleanup) runs before exit.
    func installSignalHandlers() {
        // Use a DispatchSource for safe signal handling — avoids the async-signal-safety
        // restrictions of POSIX signal handlers.
        installDispatchSignalHandler(for: SIGTERM)
        installDispatchSignalHandler(for: SIGINT)
    }

    private func installDispatchSignalHandler(for sig: Int32) {
        // Ignore the signal at the POSIX level so DispatchSource can capture it.
        signal(sig, SIG_IGN)

        let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
        source.setEventHandler {
            // Trigger a normal application termination flow
            NSApplication.shared.terminate(nil)
        }
        source.resume()
        // Keep a strong reference so the source isn't deallocated
        CrashGuard.signalSources.append(source)
    }

    /// Storage for DispatchSource objects (must remain alive for the signal to be caught).
    private static var signalSources: [DispatchSourceSignal] = []
}
