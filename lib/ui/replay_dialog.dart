import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';

import '../models/replay_request.dart';
import '../models/captured_exchange.dart';
import '../utils/body_renderer.dart';

class ReplayDialog extends ConsumerStatefulWidget {
  final ReplayRequest initialRequest;

  const ReplayDialog({super.key, required this.initialRequest});

  @override
  ConsumerState<ReplayDialog> createState() => _ReplayDialogState();
}

class _ReplayDialogState extends ConsumerState<ReplayDialog> {
  late ReplayRequest _request;
  bool _isSending = false;
  String? _error;
  late TextEditingController _urlController;
  final Map<int, TextEditingController> _nameControllers = {};
  final Map<int, TextEditingController> _valueControllers = {};

  @override
  void initState() {
    super.initState();
    _request = widget.initialRequest;
    _urlController = TextEditingController(text: _request.url);
    _urlController.addListener(() {
      _updateUrl(_urlController.text);
    });
    
    // Initialize controllers for existing headers
    for (var i = 0; i < _request.headers.length; i++) {
      _nameControllers[i] = TextEditingController(text: _request.headers[i].name);
      _valueControllers[i] = TextEditingController(text: _request.headers[i].value);
      
      // Add listeners to update headers when text changes
      final index = i;
      _nameControllers[i]!.addListener(() {
        _updateHeader(index, _nameControllers[index]!.text, _request.headers[index].value);
      });
      _valueControllers[i]!.addListener(() {
        _updateHeader(index, _request.headers[index].name, _valueControllers[index]!.text);
      });
    }
  }

  @override
  void dispose() {
    // Remove listeners and clean up controllers
    _urlController.removeListener(() {});
    _urlController.dispose();
    for (var controller in _nameControllers.values) {
      controller.removeListener(() {});
      controller.dispose();
    }
    for (var controller in _valueControllers.values) {
      controller.removeListener(() {});
      controller.dispose();
    }
    super.dispose();
  }

  void _updateUrl(String value) {
    setState(() => _request.url = value);
  }

  void _updateMethod(String? value) {
    if (value != null) {
      setState(() => _request.method = value);
    }
  }

  void _updateHeader(int index, String name, String value) {
    _request.headers[index] = HttpHeader(name, value);
  }

  void _addHeader() {
    setState(() {
      _request.headers.add(HttpHeader('', ''));
      final index = _request.headers.length - 1;
      _nameControllers[index] = TextEditingController();
      _valueControllers[index] = TextEditingController();
      // Add listeners to update headers when text changes
      _nameControllers[index]!.addListener(() {
        _updateHeader(index, _nameControllers[index]!.text, _request.headers[index].value);
      });
      _valueControllers[index]!.addListener(() {
        _updateHeader(index, _request.headers[index].name, _valueControllers[index]!.text);
      });
    });
  }

  void _removeHeader(int index) {
    setState(() {
      _request.headers.removeAt(index);
      _nameControllers.remove(index)?.dispose();
      _valueControllers.remove(index)?.dispose();
      // Reindex controllers
      for (var i = index; i < _request.headers.length; i++) {
        _nameControllers[i] = _nameControllers.remove(i + 1)!;
        _valueControllers[i] = _valueControllers.remove(i + 1)!;
      }
    });
  }

  void _updateBody(String value) {
    setState(() => _request.body = value);
  }

  Future<void> _sendRequest() async {
    // Update headers from controllers before validation
    for (var i = 0; i < _request.headers.length; i++) {
      final name = _nameControllers[i]?.text.trim() ?? '';
      final value = _valueControllers[i]?.text.trim() ?? '';
      _request.headers[i] = HttpHeader(name, value);
    }

    // Validate headers
    for (var header in _request.headers) {
      if (header.name.isEmpty || header.value.isEmpty) {
        setState(() {
          _error = 'Header name and value cannot be empty';
        });
        return;
      }
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      // TODO: Implement actual sending logic via ProxyService
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pop(_request);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _error = 'Failed to send request: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentType = _request.headers
        .firstWhere(
          (h) => h.name.toLowerCase() == 'content-type',
          orElse: () => HttpHeader('content-type', 'application/json'),
        )
        .value;

    final bodyMode = _request.body != null
        ? BodyRenderer.render(
            data: Uint8List.fromList(_request.body!.codeUnits),
            contentType: contentType,
          )
        : RenderEmpty();

    return AlertDialog(
      title: const Text('Replay Request'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<String>(
                      value: _request.method,
                      items:
                          const [
                                'GET',
                                'POST',
                                'PUT',
                                'PATCH',
                                'DELETE',
                                'HEAD',
                                'OPTIONS',
                              ]
                              .map(
                                (method) => DropdownMenuItem(
                                  value: method,
                                  child: Text(method),
                                ),
                              )
                              .toList(),
                      onChanged: _updateMethod,
                      decoration: const InputDecoration(
                        labelText: 'Method',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'URL',
                        isDense: true,
                      ),
                      textAlign: TextAlign.left,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Headers',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._request.headers.asMap().entries.map((entry) {
                final index = entry.key;
                final header = entry.value;
                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _nameControllers[index],
                        onChanged: (value) =>
                            _updateHeader(index, value, header.value),
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          isDense: true,
                        ),
                        textAlign: TextAlign.left,
                        textDirection: TextDirection.ltr,
                        cursorColor: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _valueControllers[index],
                        onChanged: (value) =>
                            _updateHeader(index, header.name, value),
                        decoration: const InputDecoration(
                          labelText: 'Value',
                          isDense: true,
                        ),
                        textAlign: TextAlign.left,
                        textDirection: TextDirection.ltr,
                        cursorColor: Colors.blue,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      onPressed: () => _removeHeader(index),
                    ),
                  ],
                );
              }),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Header'),
                onPressed: _addHeader,
              ),
              const SizedBox(height: 16),
              const Text('Body', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (bodyMode is RenderJson)
                _JsonHighlightedText((bodyMode as RenderJson).text)
              else if (bodyMode is RenderText)
                _MonospaceText((bodyMode as RenderText).text)
              else if (bodyMode is RenderHex)
                _MonospaceText((bodyMode as RenderHex).text, isHex: true)
              else
                TextField(
                  controller: TextEditingController(text: _request.body ?? ''),
                  onChanged: _updateBody,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Body',
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSending ? null : _sendRequest,
          child: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}

class _MonospaceText extends StatelessWidget {
  final String text;
  final bool isHex;

  const _MonospaceText(this.text, {this.isHex = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SelectionArea(
        child: SingleChildScrollView(
          child: Text(
            text,
            style: TextStyle(
              fontSize: isHex ? 11 : 12,
              fontFamily: 'monospace',
              height: 1.5,
            ),
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
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SelectionArea(
        child: SingleChildScrollView(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.5,
              ),
              children: _buildSpans(json, isDark),
            ),
          ),
        ),
      ),
    );
  }

  static List<TextSpan> _buildSpans(String source, bool isDark) {
    final keyColor = isDark ? const Color(0xFF9CDCFE) : const Color(0xFF0451A5);
    final stringColor = isDark
        ? const Color(0xFFCE9178)
        : const Color(0xFFA31515);
    final numberColor = isDark
        ? const Color(0xFFB5CEA8)
        : const Color(0xFF098658);
    final boolNullColor = isDark
        ? const Color(0xFF569CD6)
        : const Color(0xFF0000FF);
    final defaultColor = isDark
        ? const Color(0xFFD4D4D4)
        : const Color(0xFF1E1E1E);

    final re = RegExp(
      r'("(?:[^"]|\\")*")' // group 1 – string
      r'|(-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)' // group 2 – number
      r'|(true|false|null)' // group 3 – keyword
      r'|([{}\[\],:])' // group 4 – punctuation
      r'|(\s+)' // group 5 – whitespace
      r'|(.)', // group 6 – fallback
      dotAll: true,
    );

    final spans = <TextSpan>[];
    for (final m in re.allMatches(source)) {
      if (m.group(1) != null) {
        var i = m.end;
        while (i < source.length && (source[i] == ' ' || source[i] == '\t')) {
          i++;
        }
        final isKey = i < source.length && source[i] == ':';
        spans.add(
          TextSpan(
            text: m.group(1),
            style: TextStyle(color: isKey ? keyColor : stringColor),
          ),
        );
      } else if (m.group(2) != null) {
        spans.add(
          TextSpan(
            text: m.group(2),
            style: TextStyle(color: numberColor),
          ),
        );
      } else if (m.group(3) != null) {
        spans.add(
          TextSpan(
            text: m.group(3),
            style: TextStyle(color: boolNullColor),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: m.group(0),
            style: TextStyle(color: defaultColor),
          ),
        );
      }
    }
    return spans;
  }
}
