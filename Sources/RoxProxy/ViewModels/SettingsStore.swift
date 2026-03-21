import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    var settings: ProxySettings = ProxySettings()
    var isCATrusted: Bool = false

    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("RoxProxy/settings.json")
    }

    func load() {
        do {
            let data = try Data(contentsOf: storageURL)
            settings = try JSONDecoder().decode(ProxySettings.self, from: data)
        } catch {
            // Use defaults on first launch
            settings = ProxySettings()
        }
    }

    func save() {
        do {
            let dir = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(settings)
            try data.write(to: storageURL)
        } catch {
            // Silently fail; settings are in-memory
        }
    }

    func addDomain(_ domain: String) {
        let trimmed = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !settings.domainRules.contains(where: { $0.domain == trimmed }) else { return }
        settings.domainRules.append(DomainRule(domain: trimmed))
        save()
    }

    func removeDomain(id: UUID) {
        settings.domainRules.removeAll { $0.id == id }
        save()
    }

    func isMITMEnabled(for host: String) -> Bool {
        settings.domainRules.contains { $0.matches(host: host) }
    }
}
