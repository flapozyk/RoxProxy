import Foundation

struct DomainRule: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var domain: String      // e.g. "api.example.com" or "*.example.com"
    var isEnabled: Bool

    init(id: UUID = UUID(), domain: String, isEnabled: Bool = true) {
        self.id = id
        self.domain = domain
        self.isEnabled = isEnabled
    }

    /// Returns true if the given host matches this rule (supports * prefix wildcard).
    func matches(host: String) -> Bool {
        guard isEnabled else { return false }
        if domain.hasPrefix("*.") {
            let suffix = String(domain.dropFirst(2))
            return host == suffix || host.hasSuffix("." + suffix)
        }
        return host == domain
    }
}
