import 'package:flutter/material.dart';

import '../../models/captured_exchange.dart';

class HeadersTab extends StatelessWidget {
  final List<HttpHeader> headers;

  const HeadersTab({super.key, required this.headers});

  @override
  Widget build(BuildContext context) {
    if (headers.isEmpty) {
      return const Center(
        child: Text('No headers', style: TextStyle(color: Colors.grey)),
      );
    }
    return SelectionArea(
      child: ListView.builder(
        itemCount: headers.length,
        itemExtent: 24,
        itemBuilder: (context, index) {
          final h = headers[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: Text(
                    h.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Color(0xFF8E8E93),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    h.value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
