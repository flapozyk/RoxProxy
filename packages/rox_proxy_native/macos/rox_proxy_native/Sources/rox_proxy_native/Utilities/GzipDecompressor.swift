import Foundation
import Compression
import NIOCore
import NIOPosix

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

// MARK: - Human-readable connection error messages

/// Converts a SwiftNIO / POSIX connection error into a user-friendly string.
/// Pass `host` to include the hostname in DNS-resolution failures.
func friendlyConnectionError(_ error: Error, host: String? = nil) -> String {
    // NIOConnectionError — thrown by HappyEyeballs after all connect attempts fail.
    // It wraps both DNS errors and per-address POSIX errors.
    if let nioErr = error as? NIOConnectionError {
        let h = nioErr.host
        // DNS resolution failed
        if nioErr.dnsAError != nil || nioErr.dnsAAAAError != nil {
            return "Could not resolve hostname \"\(h)\""
        }
        // Map the first POSIX error from the connection attempts
        if let firstErr = nioErr.connectionErrors.first {
            if let msg = posixMessage(from: firstErr.error) {
                return "\(msg) (\(h))"
            }
        }
        return "Connection to \"\(h)\" failed"
    }

    // DNS / hostname resolution failures via GetaddrinfoError
    let typeName = String(describing: type(of: error))
    let desc     = error.localizedDescription

    if typeName.contains("GetaddrinfoError") ||
       desc.contains("nodename nor servname") ||
       desc.contains("Name or service not known") ||
       desc.contains("getaddrinfo") {
        if let h = host { return "Could not resolve hostname \"\(h)\"" }
        return "Could not resolve hostname"
    }

    // POSIX errors (connection-level)
    if let msg = posixMessage(from: error) { return msg }

    // NIOCore channel errors
    if let channelErr = error as? ChannelError {
        switch channelErr {
        case .connectTimeout:    return "Connection timed out"
        case .ioOnClosedChannel: return "Channel already closed"
        default: break
        }
    }

    // Strip NIO module prefixes for unrecognised errors
    return desc
        .replacingOccurrences(of: "The operation couldn't be completed. (", with: "")
        .replacingOccurrences(of: "NIOPosix.", with: "")
        .replacingOccurrences(of: "NIOCore.", with: "")
        .replacingOccurrences(of: "NIOSSL.", with: "")
        .replacingOccurrences(of: "NIOTransportServices.", with: "")
        .trimmingCharacters(in: CharacterSet(charactersIn: ")"))
}

/// Maps a POSIX or IOError to a short human-readable string, or nil if unknown.
private func posixMessage(from error: Error) -> String? {
    // NIOCore.IOError carries a raw errno code
    if let ioErr = error as? IOError {
        return posixString(errno: ioErr.errnoCode)
    }
    if let posix = error as? POSIXError {
        return posixString(errno: posix.code.rawValue)
    }
    return nil
}

private func posixString(errno code: CInt) -> String? {
    switch code {
    case ECONNREFUSED: return "Connection refused"
    case ETIMEDOUT:    return "Connection timed out"
    case ENETUNREACH:  return "Network unreachable"
    case ECONNRESET:   return "Connection reset by peer"
    case EPERM:        return "Operation not permitted"
    case EACCES:       return "Access denied"
    case EHOSTUNREACH: return "Host unreachable"
    case ENOENT:       return "No such host"
    default:           return nil
    }
}
