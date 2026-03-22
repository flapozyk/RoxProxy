import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/captured_exchange.dart';
import '../../providers/proxy_channel_provider.dart';
import '../../utils/body_renderer.dart';

enum _BodySide { request, response }

class BodyTab extends ConsumerStatefulWidget {
  final CapturedExchange exchange;
  final _BodySide side;

  const BodyTab.request({super.key, required this.exchange})
      : side = _BodySide.request;

  const BodyTab.response({super.key, required this.exchange})
      : side = _BodySide.response;

  @override
  ConsumerState<BodyTab> createState() => _BodyTabState();
}

class _BodyTabState extends ConsumerState<BodyTab> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchIfNeeded();
  }

  @override
  void didUpdateWidget(BodyTab old) {
    super.didUpdateWidget(old);
    if (old.exchange.id != widget.exchange.id) {
      _fetchIfNeeded();
    }
  }

  String? get _ref => widget.side == _BodySide.request
      ? widget.exchange.requestBodyRef
      : widget.exchange.responseBodyRef;

  Uint8List? get _cachedBytes => widget.side == _BodySide.request
      ? widget.exchange.cachedRequestBody
      : widget.exchange.cachedResponseBody;

  void _cacheBytes(Uint8List data) {
    if (widget.side == _BodySide.request) {
      widget.exchange.setCachedRequestBody(data);
    } else {
      widget.exchange.setCachedResponseBody(data);
    }
  }

  String? get _contentType {
    final headers = widget.side == _BodySide.request
        ? widget.exchange.requestHeaders
        : widget.exchange.responseHeaders;
    try {
      return headers
          ?.firstWhere(
            (h) => h.name.toLowerCase() == 'content-type',
          )
          .value
          .split(';')
          .first
          .trim();
    } catch (_) {
      return null;
    }
  }

  String? get _contentEncoding {
    final headers = widget.side == _BodySide.response
        ? widget.exchange.responseHeaders
        : null;
    try {
      return headers
          ?.firstWhere(
            (h) => h.name.toLowerCase() == 'content-encoding',
          )
          .value;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchIfNeeded() async {
    if (_cachedBytes != null) return;
    final ref = _ref;
    if (ref == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final channel = this.ref.read(proxyChannelProvider);
      Uint8List? bytes = await channel.fetchBody(ref);
      if (bytes == null) {
        setState(() => _loading = false);
        return;
      }
      // Decompress if needed
      final encoding = _contentEncoding;
      if (encoding != null &&
          (encoding.contains('gzip') || encoding.contains('deflate'))) {
        final decompressed = await channel.decompressBody(bytes, encoding);
        if (decompressed != null) bytes = decompressed;
      }
      _cacheBytes(bytes);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ref == null) {
      return const Center(
        child: Text('No body', style: TextStyle(color: Colors.grey)),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    final bytes = _cachedBytes;
    if (bytes == null) {
      return const Center(
        child: Text('No body', style: TextStyle(color: Colors.grey)),
      );
    }
    return _BodyContent(bytes: bytes, contentType: _contentType);
  }
}

class _BodyContent extends StatelessWidget {
  final Uint8List bytes;
  final String? contentType;

  const _BodyContent({required this.bytes, this.contentType});

  @override
  Widget build(BuildContext context) {
    final mode = BodyRenderer.render(data: bytes, contentType: contentType);

    return switch (mode) {
      RenderEmpty() => const Center(
          child: Text('Empty body', style: TextStyle(color: Colors.grey)),
        ),
      RenderImage(:final bytes) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Image.memory(bytes),
          ),
        ),
      RenderJson(:final text) => _MonospaceText(text),
      RenderText(:final text) => _MonospaceText(text),
      RenderHex(:final text) => _MonospaceText(text, isHex: true),
    };
  }
}

class _MonospaceText extends StatelessWidget {
  final String text;
  final bool isHex;

  const _MonospaceText(this.text, {this.isHex = false});

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: isHex ? 11 : 12,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
