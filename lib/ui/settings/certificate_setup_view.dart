import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/certificate_provider.dart';

class CertificateSetupView extends ConsumerWidget {
  const CertificateSetupView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ca = ref.watch(caTrustProvider);
    final notifier = ref.read(caTrustProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ca.trusted
                    ? Icons.verified_user_outlined
                    : Icons.gpp_bad_outlined,
                size: 20,
                color: ca.trusted
                    ? const Color(0xFF34C759)
                    : const Color(0xFFFF3B30),
              ),
              const SizedBox(width: 8),
              Text(
                ca.trusted
                    ? 'CA certificate is trusted'
                    : 'CA certificate is not trusted',
                style: TextStyle(
                  fontSize: 13,
                  color: ca.trusted
                      ? const Color(0xFF34C759)
                      : const Color(0xFFFF3B30),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                tooltip: 'Refresh',
                onPressed: notifier.refresh,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'To intercept HTTPS traffic, Rox Proxy needs its CA certificate '
            'to be trusted by macOS. Click the button below to install and '
            'trust the certificate (requires your admin password).',
            style: TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          if (ca.installError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                ca.installError!,
                style: const TextStyle(
                    color: Color(0xFFFF3B30), fontSize: 12),
              ),
            ),
          FilledButton.icon(
            onPressed: ca.isInstalling ? null : notifier.install,
            icon: ca.isInstalling
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined, size: 16),
            label: Text(ca.trusted
                ? 'Reinstall CA Certificate'
                : 'Install & Trust CA Certificate'),
            style: FilledButton.styleFrom(textStyle: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
