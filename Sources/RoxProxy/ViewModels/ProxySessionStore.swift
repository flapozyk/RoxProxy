import Foundation
import Observation

@MainActor
@Observable
final class ProxySessionStore {
    var exchanges: [CapturedExchange] = []
    var selectedExchangeID: UUID?
    var filterText: String = ""
    var isRecording: Bool = true
    var proxyState: ProxyState = .stopped

    enum ProxyState {
        case stopped
        case starting
        case running(port: Int)
        case error(String)

        var isRunning: Bool {
            if case .running = self { return true }
            return false
        }

        var description: String {
            switch self {
            case .stopped: return "Stopped"
            case .starting: return "Starting..."
            case .running(let port): return "Running on :\(port)"
            case .error(let msg): return "Error: \(msg)"
            }
        }
    }

    var filteredExchanges: [CapturedExchange] {
        guard !filterText.isEmpty else { return exchanges }
        let query = filterText.lowercased()
        return exchanges.filter {
            $0.url.lowercased().contains(query) ||
            $0.host.lowercased().contains(query) ||
            $0.method.lowercased().contains(query)
        }
    }

    var selectedExchange: CapturedExchange? {
        guard let id = selectedExchangeID else { return nil }
        return exchanges.first { $0.id == id }
    }

    func append(_ exchange: CapturedExchange) {
        guard isRecording else { return }
        exchanges.append(exchange)
    }

    func update(_ exchange: CapturedExchange) {
        guard let idx = exchanges.firstIndex(where: { $0.id == exchange.id }) else { return }
        exchanges[idx] = exchange
    }

    func clear() {
        exchanges.removeAll()
        selectedExchangeID = nil
    }
}
