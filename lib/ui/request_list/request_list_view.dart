import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/captured_exchange.dart';
import '../../providers/exchange_provider.dart';
import '../../providers/proxy_channel_provider.dart';
import '../../utils/data_formatting.dart';
import '../components/https_indicator.dart';
import '../components/method_badge.dart';
import '../components/status_indicator.dart';

class RequestListView extends ConsumerWidget {
  const RequestListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exchanges = ref.watch(filteredExchangesProvider);
    final selectedId = ref.watch(selectedExchangeIdProvider);

    return Column(
      children: [
        _ColumnHeader(),
        const Divider(height: 1),
        Expanded(
          child: exchanges.isEmpty
              ? const Center(
                  child: Text(
                    'No requests captured',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: exchanges.length,
                  itemExtent: 28,
                  itemBuilder: (context, index) {
                    final exchange = exchanges[index];
                    final isSelected = exchange.id == selectedId;
                    return _ExchangeRow(
                      exchange: exchange,
                      isSelected: isSelected,
                      onTap: () => ref
                          .read(selectedExchangeIdProvider.notifier)
                          .state = exchange.id,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          const SizedBox(width: 20), // HTTPS icon
          const SizedBox(width: 8),
          const SizedBox(width: 70, child: _HeaderLabel('Method')),
          const SizedBox(width: 8),
          const SizedBox(width: 48, child: _HeaderLabel('Status')),
          const SizedBox(width: 8),
          const SizedBox(width: 160, child: _HeaderLabel('Host')),
          const SizedBox(width: 8),
          const Expanded(child: _HeaderLabel('Path')),
          const SizedBox(width: 8),
          const SizedBox(width: 64, child: _HeaderLabel('Duration')),
          const SizedBox(width: 8),
          const SizedBox(width: 64, child: _HeaderLabel('Size')),
        ],
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  final String label;
  const _HeaderLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ExchangeRow extends ConsumerWidget {
  final CapturedExchange exchange;
  final bool isSelected;
  final VoidCallback onTap;

  const _ExchangeRow({
    required this.exchange,
    required this.isSelected,
    required this.onTap,
  });

  bool get _canCopyCurl => !exchange.isHTTPS || exchange.isMITMDecrypted;

  Future<void> _copyAsCurl(BuildContext context, WidgetRef ref) async {
    var bodyBytes = exchange.cachedRequestBody;
    if (bodyBytes == null && exchange.requestBodyRef != null) {
      bodyBytes = await ref
          .read(proxyChannelProvider)
          .fetchBody(exchange.requestBodyRef!);
      if (bodyBytes != null) exchange.setCachedRequestBody(bodyBytes);
    }
    final curl = DataFormatting.buildCurlCommand(exchange, bodyBytes: bodyBytes);
    await Clipboard.setData(ClipboardData(text: curl));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('cURL copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showContextMenu(
      BuildContext context, WidgetRef ref, Offset globalPosition) async {
    if (!_canCopyCurl) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'curl',
          child: Text('Copy as cURL', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
    if (result == 'curl' && context.mounted) {
      await _copyAsCurl(context, ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      onSecondaryTapDown: _canCopyCurl
          ? (d) => _showContextMenu(context, ref, d.globalPosition)
          : null,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.transparent,
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: HttpsIndicator(
                isHTTPS: exchange.isHTTPS,
                isMITMDecrypted: exchange.isMITMDecrypted,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 70, child: MethodBadge(exchange.method)),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              child: StatusIndicator(
                statusCode: exchange.statusCode,
                state: exchange.state,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 160,
              child: Text(
                exchange.host,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Tooltip(
                message: exchange.url,
                waitDuration: const Duration(milliseconds: 500),
                child: Text(
                  exchange.path,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: Text(
                DataFormatting.formatDuration(exchange.duration),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 64,
              child: Text(
                exchange.responseSize != null
                    ? DataFormatting.formatSize(exchange.responseSize!)
                    : '—',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
