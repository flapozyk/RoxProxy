import Foundation

/// Classifies body content and produces a display-ready string or rendering hint.
enum BodyRenderer {

    enum RenderMode {
        /// Display as a JSON-formatted string.
        case json(String)
        /// Display as a monospaced text string.
        case text(String)
        /// Render as an image (pass raw data to NSImage / Image(nsImage:)).
        case image(Data)
        /// Display as a hex dump.
        case hex(String)
        /// Nothing to show.
        case empty
    }

    /// Determines how to render `data` given the `Content-Type` and
    /// `Content-Encoding` header values.
    static func render(
        data: Data,
        contentType: String,
        contentEncoding: String = ""
    ) -> RenderMode {
        guard !data.isEmpty else { return .empty }

        // Decompress if needed
        let decoded: Data
        if contentEncoding.isEmpty || contentEncoding.lowercased() == "identity" {
            decoded = data
        } else {
            decoded = GzipDecompressor.decode(data: data, contentEncoding: contentEncoding) ?? data
        }

        let ct = contentType.lowercased()

        // Image types
        if ct.contains("image/") {
            return .image(decoded)
        }

        // JSON — attempt pretty-print
        if ct.contains("json") || ct.contains("javascript") {
            if let str = toString(decoded), let pretty = prettyJSON(str) {
                return .json(pretty)
            }
        }

        // Any other text-like type
        if ct.contains("text") || ct.contains("html") || ct.contains("xml")
            || ct.contains("javascript") || ct.isEmpty
        {
            if let str = toString(decoded) {
                // Try JSON even for text/plain (some APIs use it)
                if let pretty = prettyJSON(str) { return .json(pretty) }
                return .text(str)
            }
        }

        // Binary fallback — hex dump
        return .hex(hexDump(decoded))
    }

    // MARK: - Helpers

    private static func toString(_ data: Data) -> String? {
        String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
    }

    private static func prettyJSON(_ raw: String) -> String? {
        guard let data = raw.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data, options: []),
              let pretty = try? JSONSerialization.data(
                withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]
              ),
              let str = String(data: pretty, encoding: .utf8)
        else { return nil }
        return str
    }

    /// Returns a formatted hex dump: `0000  48 65 6c 6c 6f  Hello`
    static func hexDump(_ data: Data, bytesPerLine: Int = 16) -> String {
        var lines: [String] = []
        var offset = 0
        while offset < data.count {
            let slice = data[offset ..< min(offset + bytesPerLine, data.count)]
            let hex   = slice.map { String(format: "%02x", $0) }.joined(separator: " ")
            let ascii = slice.map { ($0 >= 32 && $0 < 127) ? Character(Unicode.Scalar($0)) : "." }
            let asciiStr = String(ascii)
            let padded = hex.padding(toLength: bytesPerLine * 3 - 1, withPad: " ", startingAt: 0)
            lines.append(String(format: "%04x  %@  %@", offset, padded, asciiStr))
            offset += bytesPerLine
        }
        return lines.joined(separator: "\n")
    }
}
