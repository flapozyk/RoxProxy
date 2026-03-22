import 'dart:convert';
import 'dart:typed_data';

sealed class RenderMode {}

class RenderJson extends RenderMode {
  final String text;
  RenderJson(this.text);
}

class RenderText extends RenderMode {
  final String text;
  RenderText(this.text);
}

class RenderImage extends RenderMode {
  final Uint8List bytes;
  RenderImage(this.bytes);
}

class RenderHex extends RenderMode {
  final String text;
  RenderHex(this.text);
}

class RenderEmpty extends RenderMode {}

class BodyRenderer {
  static const int _bytesPerLine = 16;

  static RenderMode render({
    required Uint8List data,
    String? contentType,
    bool isTruncated = false,
  }) {
    if (data.isEmpty) return RenderEmpty();

    final ct = contentType?.toLowerCase() ?? '';

    // Image
    if (ct.startsWith('image/')) {
      return RenderImage(data);
    }

    // JSON
    if (ct.contains('json') || ct.contains('javascript')) {
      final str = _toString(data);
      if (str != null) {
        final pretty = _prettyJson(str);
        if (pretty != null) return RenderJson(pretty);
        return RenderText(str);
      }
    }

    // Text-like types
    if (ct.isEmpty ||
        ct.startsWith('text/') ||
        ct.contains('xml') ||
        ct.contains('html') ||
        ct.contains('form-urlencoded')) {
      final str = _toString(data);
      if (str != null) return RenderText(str);
    }

    // Fallback: hex dump
    return RenderHex(_hexDump(data));
  }

  static String? _toString(Uint8List data) {
    try {
      return utf8.decode(data);
    } catch (_) {
      try {
        return latin1.decode(data);
      } catch (_) {
        return null;
      }
    }
  }

  static String? _prettyJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return null;
    }
  }

  static String _hexDump(Uint8List data) {
    final sb = StringBuffer();
    for (var i = 0; i < data.length; i += _bytesPerLine) {
      final end = (i + _bytesPerLine).clamp(0, data.length);
      final chunk = data.sublist(i, end);

      // Offset
      sb.write('${i.toRadixString(16).padLeft(8, '0')}  ');

      // Hex bytes
      for (var j = 0; j < _bytesPerLine; j++) {
        if (j < chunk.length) {
          sb.write(chunk[j].toRadixString(16).padLeft(2, '0'));
          sb.write(' ');
        } else {
          sb.write('   ');
        }
        if (j == 7) sb.write(' ');
      }

      // ASCII
      sb.write(' |');
      for (final byte in chunk) {
        sb.write((byte >= 0x20 && byte < 0x7f) ? String.fromCharCode(byte) : '.');
      }
      sb.write('|\n');
    }
    return sb.toString();
  }
}
