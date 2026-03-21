import SwiftUI

struct HeadersTabView: View {
    let headers: [(name: String, value: String)]

    var body: some View {
        if headers.isEmpty {
            ContentUnavailableView("No Headers", systemImage: "list.bullet")
        } else {
            Table(headers.map(NamedHeader.init)) {
                TableColumn("Name") { h in
                    Text(h.name)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .width(min: 120, ideal: 200)

                TableColumn("Value") { h in
                    Text(h.value)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
            .tableStyle(.inset)
        }
    }
}

// Identifiable wrapper so Table can use the tuple-based headers
private struct NamedHeader: Identifiable {
    let id = UUID()
    let name: String
    let value: String

    init(_ tuple: (name: String, value: String)) {
        self.name  = tuple.name
        self.value = tuple.value
    }
}
