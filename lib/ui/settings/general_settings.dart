import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_provider.dart';

class GeneralSettings extends ConsumerStatefulWidget {
  const GeneralSettings({super.key});

  @override
  ConsumerState<GeneralSettings> createState() => _GeneralSettingsState();
}

class _GeneralSettingsState extends ConsumerState<GeneralSettings> {
  late final TextEditingController _portController;
  late final TextEditingController _maxExchangesController;
  late final TextEditingController _timeoutController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _portController = TextEditingController(text: settings.port.toString());
    _maxExchangesController =
        TextEditingController(text: settings.maxExchanges.toString());
    _timeoutController = TextEditingController(
        text: settings.connectionTimeoutSeconds.toString());
  }

  @override
  void dispose() {
    _portController.dispose();
    _maxExchangesController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('Proxy'),
        _FormRow(
          label: 'Port',
          child: SizedBox(
            width: 100,
            child: TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 13),
              decoration: _inputDecoration(),
              onSubmitted: (v) {
                final port = int.tryParse(v);
                if (port != null && port > 0 && port < 65536) {
                  notifier.setPort(port);
                }
              },
            ),
          ),
        ),
        _FormRow(
          label: 'Auto-start on launch',
          child: Switch(
            value: settings.autoStartProxy,
            onChanged: notifier.setAutoStartProxy,
          ),
        ),
        _FormRow(
          label: 'Configure macOS system proxy',
          child: Switch(
            value: settings.setSystemProxy,
            onChanged: notifier.setSetSystemProxy,
          ),
        ),
        _FormRow(
          label: 'Connection timeout (seconds)',
          child: SizedBox(
            width: 100,
            child: TextField(
              controller: _timeoutController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 13),
              decoration: _inputDecoration(),
              onSubmitted: (v) {
                final t = int.tryParse(v);
                if (t != null && t > 0) notifier.setConnectionTimeout(t);
              },
            ),
          ),
        ),
        const Divider(height: 24),
        _SectionLabel('Traffic'),
        _FormRow(
          label: 'Max captured exchanges',
          child: SizedBox(
            width: 100,
            child: TextField(
              controller: _maxExchangesController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 13),
              decoration: _inputDecoration(),
              onSubmitted: (v) {
                final n = int.tryParse(v);
                if (n != null && n > 0) notifier.setMaxExchanges(n);
              },
            ),
          ),
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration() => InputDecoration(
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _FormRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          child,
        ],
      ),
    );
  }
}
