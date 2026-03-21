import Foundation
import Compression

/// Decompresses gzip / deflate / zlib encoded data using the system Compression framework.
enum GzipDecompressor {

    enum Error: Swift.Error, LocalizedError {
        case decompressedSizeUnknown
        case decompressedBufferTooSmall
        case decompressionFailed

        var errorDescription: String? {
            switch self {
            case .decompressedSizeUnknown:     return "Cannot determine decompressed size."
            case .decompressedBufferTooSmall:  return "Decompressed data exceeded buffer."
            case .decompressionFailed:         return "Decompression failed."
            }
        }
    }

    /// Decompresses data encoded with gzip (strips the 10-byte gzip header/trailer,
    /// then uses raw DEFLATE).
    static func decompress(gzip data: Data) throws -> Data {
        // gzip: 10-byte header + data + 8-byte trailer
        guard data.count > 18 else { throw Error.decompressionFailed }
        let deflated = data[10 ..< data.count - 8]
        return try decompress(deflate: deflated)
    }

    /// Decompresses zlib-wrapped deflate data (skip 2-byte zlib header + 4-byte checksum).
    static func decompress(zlib data: Data) throws -> Data {
        guard data.count > 6 else { throw Error.decompressionFailed }
        let deflated = data[2 ..< data.count - 4]
        return try decompress(deflate: deflated)
    }

    /// Decompresses raw DEFLATE data using the Apple Compression framework.
    static func decompress(deflate data: Data) throws -> Data {
        // Allocate an output buffer; grow up to 16× the input size if needed
        var outputSize = max(data.count * 4, 64 * 1024)
        var output = Data(count: outputSize)
        var written: Int = 0

        for _ in 0 ..< 4 {
            written = data.withUnsafeBytes { src in
                output.withUnsafeMutableBytes { dst in
                    compression_decode_buffer(
                        dst.bindMemory(to: UInt8.self).baseAddress!,
                        outputSize,
                        src.bindMemory(to: UInt8.self).baseAddress!,
                        data.count,
                        nil,
                        COMPRESSION_ZLIB
                    )
                }
            }
            if written == outputSize {
                // Buffer was too small — double and retry
                outputSize *= 2
                output = Data(count: outputSize)
            } else {
                break
            }
        }

        guard written > 0 && written < outputSize else {
            throw Error.decompressedBufferTooSmall
        }
        return output.prefix(written)
    }

    // MARK: - Convenience

    /// Decodes data based on a `Content-Encoding` header value.
    /// Returns `nil` if the encoding is not supported (e.g. brotli).
    static func decode(data: Data, contentEncoding: String) -> Data? {
        let enc = contentEncoding.lowercased().trimmingCharacters(in: .whitespaces)
        switch enc {
        case "gzip":
            return try? decompress(gzip: data)
        case "deflate":
            // "deflate" in HTTP is actually zlib-wrapped deflate in most implementations
            return (try? decompress(zlib: data)) ?? (try? decompress(deflate: data))
        case "identity", "":
            return data
        default:
            return nil
        }
    }
}
