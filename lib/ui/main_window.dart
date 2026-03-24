import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/proxy_settings.dart';
import '../models/proxy_state.dart';
import '../providers/exchange_provider.dart';
import '../providers/proxy_control_provider.dart';
import '../providers/settings_provider.dart';
import 'components/ca_warning_banner.dart';
import 'components/status_bar.dart';
import 'detail/detail_view.dart';
import 'request_list/request_list_view.dart';
import 'settings/settings_view.dart';

class MainWindow extends ConsumerStatefulWidget {
  const MainWindow({super.key});

  @override
  ConsumerState<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends ConsumerState<MainWindow> {
  bool _autoStartDone = false;
  List<String>? _lastDomainRuleIds;

  @override
  void initState() {
    super.initState();
    // Handle the rare case where settings load completes before the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(settingsLoadedProvider)) _maybeAutoStart();
    });
  }

  void _maybeAutoStart() {
    if (_autoStartDone) return;
    _autoStartDone = true;
    final settings = ref.read(settingsProvider);
    if (settings.autoStartProxy) {
      ref.read(proxyStateProvider.notifier).start(settings);
    }
  }

  /// Restarts the proxy whenever domain rules change while it's running,
  /// so MITM rules take effect immediately without a manual stop/start.
  void _maybeRestartForRuleChange(ProxySettings settings) {
    // Ignore calls before settings are loaded from disk — the default empty
    // rules would look like a "change" compared to the real saved rules.
    if (!ref.read(settingsLoadedProvider)) return;

    final currentIds =
        settings.domainRules.map((r) => '${r.id}:${r.isEnabled}').toList()
          ..sort();

    final proxyState = ref.read(proxyStateProvider);
    if (proxyState.isRunning &&
        _lastDomainRuleIds != null &&
        !listEquals(_lastDomainRuleIds, currentIds)) {
      final notifier = ref.read(proxyStateProvider.notifier);
      notifier.stop().then((_) => notifier.start(settings));
    }

    _lastDomainRuleIds = currentIds;
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (_) => const Dialog(
        child: SizedBox(width: 520, height: 480, child: SettingsView()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Auto-start once settings are loaded from disk (ref.listen is valid here).
    ref.listen(settingsLoadedProvider, (_, isLoaded) {
      if (isLoaded) _maybeAutoStart();
    });

    final proxyState = ref.watch(proxyStateProvider);
    final filterText = ref.watch(filterTextProvider);
    final exchanges = ref.watch(exchangeListProvider);
    final selectedExchange = ref.watch(selectedExchangeProvider);
    final settings = ref.watch(settingsProvider);
    final isRecording = settings.isRecording;

    // Restart proxy if domain rules changed while running
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _maybeRestartForRuleChange(settings));

    return Scaffold(
      appBar: _buildToolbar(context, proxyState, isRecording, exchanges.isEmpty),
      body: Column(
        children: [
          CaWarningBanner(onOpenSettings: _openSettings),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sidebar: request list
                SizedBox(
                  width: 520,
                  child: Column(
                    children: [
                      _SearchBar(
                        text: filterText,
                        onChanged: (v) =>
                            ref.read(filterTextProvider.notifier).state = v,
                      ),
                      const Divider(height: 1),
                      const Expanded(child: RequestListView()),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                // Detail pane
                Expanded(
                  child: selectedExchange != null
                      ? DetailView(exchange: selectedExchange)
                      : const _EmptyDetail(),
                ),
              ],
            ),
          ),
          const StatusBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildToolbar(
    BuildContext context,
    ProxyState proxyState,
    bool isRecording,
    bool exchangesEmpty,
  ) {
    return AppBar(
      toolbarHeight: 44,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 12,
      title: const Text('Rox Proxy',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      actions: [
        // Start / Stop
        _ToolbarButton(
          icon: proxyState.isRunning ? Icons.stop_circle_outlined : Icons.play_circle_outlined,
          label: proxyState.isRunning ? 'Stop' : 'Start',
          color: proxyState.isRunning
              ? const Color(0xFFFF3B30)
              : const Color(0xFF34C759),
          enabled: proxyState is! ProxyStarting,
          onPressed: () {
            if (proxyState.isRunning) {
              ref.read(proxyStateProvider.notifier).stop();
            } else {
              final settings = ref.read(settingsProvider);
              ref.read(proxyStateProvider.notifier).start(settings);
            }
          },
        ),
        const SizedBox(width: 4),
        // Record toggle
        _ToolbarButton(
          icon: isRecording ? Icons.fiber_manual_record : Icons.fiber_manual_record_outlined,
          label: isRecording ? 'Pause' : 'Record',
          color: isRecording ? const Color(0xFFFF3B30) : null,
          onPressed: () {
            final notifier = ref.read(settingsProvider.notifier);
            notifier.setIsRecording(!isRecording);
          },
        ),
        const SizedBox(width: 4),
        // Clear
        _ToolbarButton(
          icon: Icons.delete_outline,
          label: 'Clear',
          enabled: !exchangesEmpty,
          onPressed: () => ref.read(exchangeListProvider.notifier).clear(),
        ),
        const SizedBox(width: 4),
        // Settings
        _ToolbarButton(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onPressed: _openSettings,
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Divider(height: 0.5, color: Theme.of(context).dividerColor),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  final String text;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.text, required this.onChanged});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Filter requests…',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search, size: 16),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 14),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final bool enabled;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.onPressed,
    this.color,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: enabled ? effectiveColor : effectiveColor.withAlpha(80),
        onPressed: enabled ? onPressed : null,
        splashRadius: 18,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      ),
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_tethering,
              size: 48, color: Colors.grey.withAlpha(100)),
          const SizedBox(height: 12),
          Text(
            'Select a request to inspect',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
