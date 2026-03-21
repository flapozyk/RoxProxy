import SwiftUI

struct DetailView: View {
    let exchange: CapturedExchange
    @State private var selectedTab: DetailTab = .response

    enum DetailTab: String, CaseIterable {
        case request  = "Request"
        case response = "Response"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Summary bar
            SummaryBar(exchange: exchange)
            Divider()

            // Tab selector
            Picker("", selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Tab content
            switch selectedTab {
            case .request:
                RequestPane(exchange: exchange)
            case .response:
                ResponsePane(exchange: exchange)
            }
        }
    }
}

// MARK: - Summary Bar

private struct SummaryBar: View {
    let exchange: CapturedExchange

    var body: some View {
        HStack(spacing: 8) {
            MethodBadge(method: exchange.method)

            Text(exchange.url)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            if exchange.statusCode != nil {
                StatusView(exchange: exchange)
            }

            if let duration = exchange.duration {
                Text(DataFormatting.formatDuration(duration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let size = exchange.responseSize {
                Text(DataFormatting.formatSize(size))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Request Pane

private struct RequestPane: View {
    let exchange: CapturedExchange
    @State private var subTab: SubTab = .headers

    enum SubTab: String, CaseIterable {
        case headers = "Headers"
        case body    = "Body"
    }

    var body: some View {
        VStack(spacing: 0) {
            subTabPicker
            Divider()
            switch subTab {
            case .headers:
                HeadersTabView(headers: exchange.requestHeaders)
            case .body:
                BodyTabView(bodyContent: exchange.requestBody, headers: exchange.requestHeaders)
            }
        }
    }

    private var subTabPicker: some View {
        HStack {
            Picker("", selection: $subTab) {
                ForEach(SubTab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

// MARK: - Response Pane

private struct ResponsePane: View {
    let exchange: CapturedExchange
    @State private var subTab: SubTab = .body

    enum SubTab: String, CaseIterable {
        case headers = "Headers"
        case body    = "Body"
    }

    var body: some View {
        VStack(spacing: 0) {
            subTabPicker
            Divider()
            switch subTab {
            case .headers:
                HeadersTabView(headers: exchange.responseHeaders ?? [])
            case .body:
                BodyTabView(
                    bodyContent: exchange.responseBody,
                    headers: exchange.responseHeaders ?? []
                )
            }
        }
    }

    private var subTabPicker: some View {
        HStack {
            Picker("", selection: $subTab) {
                ForEach(SubTab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)

            if case .failed(let msg) = exchange.state {
                Label(msg, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}
