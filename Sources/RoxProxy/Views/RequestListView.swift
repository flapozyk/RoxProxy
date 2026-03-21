import SwiftUI

struct RequestListView: View {
    @Environment(ProxySessionStore.self) private var sessionStore

    var body: some View {
        @Bindable var store = sessionStore

        Table(sessionStore.filteredExchanges, selection: $store.selectedExchangeID) {
            TableColumn("") { exchange in
                HTTPSIndicator(isHTTPS: exchange.isHTTPS, isMITM: exchange.isMITMDecrypted)
            }
            .width(16)

            TableColumn("Method") { exchange in
                MethodBadge(method: exchange.method)
            }
            .width(65)

            TableColumn("Status") { exchange in
                StatusView(exchange: exchange)
            }
            .width(50)

            TableColumn("Host", value: \.host)
                .width(min: 80, ideal: 140)

            TableColumn("Path", value: \.path)
                .width(min: 100, ideal: 220)

            TableColumn("Duration") { exchange in
                Group {
                    if let d = exchange.duration {
                        Text(DataFormatting.formatDuration(d))
                    } else {
                        Text("—")
                    }
                }
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(exchange.duration == nil ? Color.secondary : Color.primary)
            }
            .width(70)

            TableColumn("Size") { exchange in
                Group {
                    if let size = exchange.responseSize {
                        Text(DataFormatting.formatSize(size))
                    } else {
                        Text("—")
                    }
                }
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(exchange.responseSize == nil ? Color.secondary : Color.primary)
            }
            .width(70)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 28)
        }
    }
}
