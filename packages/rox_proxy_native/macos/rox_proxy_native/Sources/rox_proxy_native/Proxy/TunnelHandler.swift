import NIOCore

/// Blindly relays bytes between two channels (inbound ↔ upstream).
///
/// Installed after the HTTP codec is removed from the pipeline when the proxy
/// establishes a CONNECT tunnel.  One instance is added to each side; the
/// `peer` property points to the other channel so bytes can be forwarded.
final class TunnelHandler: ChannelDuplexHandler {
    typealias InboundIn   = ByteBuffer
    typealias InboundOut  = ByteBuffer
    typealias OutboundIn  = ByteBuffer
    typealias OutboundOut = ByteBuffer

    /// The other end of the tunnel.  Set right after both channels are ready.
    var peer: Channel?

    // MARK: - Inbound → peer

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        guard let peer else {
            context.close(promise: nil)
            return
        }
        // Forward to peer; back-pressure: pause reads if peer write buffer grows
        let buf = unwrapInboundIn(data)
        peer.writeAndFlush(NIOAny(buf)).whenFailure { _ in
            context.close(promise: nil)
        }
    }

    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    // MARK: - Closure propagation

    func channelInactive(context: ChannelHandlerContext) {
        peer?.close(promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        peer?.close(promise: nil)
        context.close(promise: nil)
    }
}
