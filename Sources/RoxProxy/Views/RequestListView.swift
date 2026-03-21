import SwiftUI
import AppKit

struct RequestListView: View {
    @Environment(ProxySessionStore.self) private var sessionStore
    @State private var toolbarHeight: CGFloat = 0

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
        .padding(.top, toolbarHeight)
        .background(alignment: .top) {
            ToolbarHeightProbe { height in
                if height > 0 { toolbarHeight = height }
            }
            .frame(width: 0, height: 0)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 28)
        }
    }
}

// MARK: - AppKit toolbar height probe

private struct ToolbarHeightProbe: NSViewRepresentable {
    let onHeight: (CGFloat) -> Void

    func makeNSView(context: Context) -> ProbeView {
        ProbeView(onHeight: onHeight)
    }

    func updateNSView(_ nsView: ProbeView, context: Context) {}

    final class ProbeView: NSView {
        let onHeight: (CGFloat) -> Void

        init(onHeight: @escaping (CGFloat) -> Void) {
            self.onHeight = onHeight
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, let contentView = window.contentView else { return }
            // contentLayoutRect is in window coords (origin bottom-left).
            // Its maxY is the top of the usable content area (below toolbar).
            // Toolbar height = contentView.frame.height - contentLayoutRect.maxY
            let h = contentView.frame.height - window.contentLayoutRect.maxY
            DispatchQueue.main.async { self.onHeight(max(h, 0)) }
        }
    }
}
