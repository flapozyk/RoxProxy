import 'package:flutter/material.dart';

class HttpsIndicator extends StatelessWidget {
  final bool isHTTPS;
  final bool isMITMDecrypted;

  const HttpsIndicator({
    super.key,
    required this.isHTTPS,
    required this.isMITMDecrypted,
  });

  @override
  Widget build(BuildContext context) {
    if (!isHTTPS) return const SizedBox(width: 16);
    return Icon(
      isMITMDecrypted ? Icons.lock_open : Icons.lock,
      size: 14,
      color: isMITMDecrypted
          ? const Color(0xFFFF9500)
          : const Color(0xFF34C759),
    );
  }
}
