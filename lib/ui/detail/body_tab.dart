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
      RenderJson(:final text) => _JsonHighlightedText(text),
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

class _JsonHighlightedText extends StatelessWidget {
  final String json;
  const _JsonHighlightedText(this.json);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.5),
            children: _buildSpans(json, isDark),
          ),
        ),
      ),
    );
  }

  static List<TextSpan> _buildSpans(String source, bool isDark) {
    // VS Code–inspired palette, dark and light variants
    final keyColor      = isDark ? const Color(0xFF9CDCFE) : const Color(0xFF0451A5);
    final stringColor   = isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515);
    final numberColor   = isDark ? const Color(0xFFB5CEA8) : const Color(0xFF098658);
    final boolNullColor = isDark ? const Color(0xFF569CD6) : const Color(0xFF0000FF);
    final defaultColor  = isDark ? const Color(0xFFD4D4D4) : const Color(0xFF1E1E1E);

    final re = RegExp(
      r'("(?:[^"\\]|\\.)*")'    // group 1 – string
      r'|(-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)' // group 2 – number
      r'|(true|false|null)'     // group 3 – keyword
      r'|([{}\[\],:])'          // group 4 – punctuation
      r'|(\s+)'                 // group 5 – whitespace
      r'|(.)',                  // group 6 – fallback
      dotAll: true,
    );

    final spans = <TextSpan>[];
    for (final m in re.allMatches(source)) {
      if (m.group(1) != null) {
        // Determine key vs string value: look ahead for ':'
        var i = m.end;
        while (i < source.length && (source[i] == ' ' || source[i] == '\t')) {
          i++;
        }
        final isKey = i < source.length && source[i] == ':';
        spans.add(TextSpan(
          text: m.group(1),
          style: TextStyle(color: isKey ? keyColor : stringColor),
        ));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(text: m.group(2), style: TextStyle(color: numberColor)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(text: m.group(3), style: TextStyle(color: boolNullColor)));
      } else {
        spans.add(TextSpan(text: m.group(0), style: TextStyle(color: defaultColor)));
      }
    }
    return spans;
  }
}
