import SwiftUI

/// Renders a captured HTTP body: JSON (pretty-printed), text, image, or hex dump.
struct BodyTabView: View {
    let bodyContent: BodyContent?
    let headers: [(name: String, value: String)]

    private var contentType: String {
        headers.first(where: { $0.name.lowercased() == "content-type" })?.value ?? ""
    }

    private var contentEncoding: String {
        headers.first(where: { $0.name.lowercased() == "content-encoding" })?.value ?? ""
    }

    var body: some View {
        Group {
            switch bodyContent {
            case nil, .empty:
                ContentUnavailableView("No Body", systemImage: "tray")

            case .data(let data), .truncated(let data, _):
                VStack(spacing: 0) {
                    if case .truncated(_, let total) = bodyContent {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text("Showing first \(DataFormatting.formatSize(BodyContent.maxInMemorySize)) of \(DataFormatting.formatSize(total))")
                                .font(.caption)
                        }
                        .foregroundStyle(.orange)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        Divider()
                    }

                    RenderedBodyView(
                        data: data,
                        contentType: contentType,
                        contentEncoding: contentEncoding
                    )
                }

            case .some(_):
                ContentUnavailableView("No Body", systemImage: "tray")
            }
        }
    }
}

// MARK: - Rendered body view

private struct RenderedBodyView: View {
    let data: Data
    let contentType: String
    let contentEncoding: String

    private var renderMode: BodyRenderer.RenderMode {
        BodyRenderer.render(data: data, contentType: contentType, contentEncoding: contentEncoding)
    }

    var body: some View {
        switch renderMode {
        case .json(let str), .text(let str):
            ScrollView([.horizontal, .vertical]) {
                Text(str)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
            }

        case .image(let imgData):
            if let nsImage = NSImage(data: imgData) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                }
            } else {
                ContentUnavailableView("Cannot display image", systemImage: "photo.slash")
            }

        case .hex(let dump):
            ScrollView([.horizontal, .vertical]) {
                Text(dump)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
            }

        case .empty:
            ContentUnavailableView("No Body", systemImage: "tray")
        }
    }
}
