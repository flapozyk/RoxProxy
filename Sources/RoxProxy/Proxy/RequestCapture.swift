import Foundation
import NIOCore
import NIOHTTP1

/// Accumulates NIO HTTP body chunks into a ``BodyContent`` value, respecting the 10 MB cap.
/// Used by proxy handlers to build captured request and response bodies incrementally.
final class RequestCapture {

    private(set) var bodyContent: BodyContent?
    private(set) var totalBytes: Int = 0

    func append(_ buffer: ByteBuffer) {
        let data = Data(buffer.readableBytesView)
        bodyContent = BodyContent.appending(
            existing: bodyContent,
            newBytes: data,
            runningTotal: &totalBytes
        )
    }

    func reset() {
        bodyContent = nil
        totalBytes = 0
    }

    /// Convenience: build from an array of buffers (e.g. buffered request body).
    static func build(from buffers: [ByteBuffer]) -> (content: BodyContent?, size: Int) {
        let capture = RequestCapture()
        for buf in buffers { capture.append(buf) }
        return (capture.bodyContent, capture.totalBytes)
    }
}
