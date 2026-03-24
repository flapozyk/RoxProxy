import Foundation

/// Thread-safe in-memory store for request/response body bytes.
/// Bodies are keyed by UUID string so Flutter can fetch them lazily
/// via the 'fetchBody' MethodChannel call.
final class BodyStore: @unchecked Sendable {

    private let lock = NSLock()
    private var store: [String: Data] = [:]

    /// Stores the request and response bodies of an exchange (if any)
    /// and returns the reference UUIDs assigned to each.
    func store(exchange: CapturedExchange) -> (request: String?, response: String?) {
        let reqRef = storeBodyContent(exchange.requestBody)
        let resRef = storeBodyContent(exchange.responseBody)
        return (request: reqRef, response: resRef)
    }

    /// Stores a single body Data and returns its reference UUID, or nil if empty.
    private func storeBodyContent(_ content: BodyContent?) -> String? {
        guard let content, let data = content.data, !data.isEmpty else { return nil }
        let ref = UUID().uuidString
        lock.withLock { store[ref] = data }
        return ref
    }

    /// Retrieves body bytes by reference. Returns nil if not found.
    func fetch(ref: String) -> Data? {
        lock.withLock { store[ref] }
    }

    /// Releases a single body reference.
    func release(ref: String) {
        lock.withLock { store.removeValue(forKey: ref) }
    }

    /// Releases all cached bodies.
    func releaseAll() {
        lock.withLock { store.removeAll() }
    }
}
