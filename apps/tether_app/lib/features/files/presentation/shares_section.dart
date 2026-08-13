import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/domain/device.dart';
import '../../devices/providers/devices_provider.dart';
import '../../../core/theme/dracula_palette.dart';
import '../domain/share.dart';
import '../providers/downloads_provider.dart';
import '../providers/shares_provider.dart';

enum _SharesFilter { received, sent }

/// Pestaña "Compartidos": recibidos (aceptar/descargar) y enviados (estado).
class SharesTab extends ConsumerStatefulWidget {
  const SharesTab({super.key});

  @override
  ConsumerState<SharesTab> createState() => _SharesTabState();
}

class _SharesTabState extends ConsumerState<SharesTab> {
  _SharesFilter _filter = _SharesFilter.received;

  Future<void> _accept(Share share) async {
    try {
      await ref.read(sharesControllerProvider.notifier).accept(share.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo aceptar el share.')),
        );
      }
    }
  }

  Future<void> _download(Share share) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await ref
          .read(sharesControllerProvider.notifier)
          .getDownloadUrl(share.id);
      if (!mounted || url == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('El share está expirado.')),
        );
        return;
      }
      final location = await getSaveLocation(
        suggestedName: share.file?.name ?? 'archivo',
      );
      if (location == null) return;

      final name = share.file?.name ?? 'archivo';
      final ok = await ref.read(downloadsControllerProvider.notifier).start(
            name: name,
            url: url,
            savePath: location.path,
          );
      if (ok) {
        await ref
            .read(sharesControllerProvider.notifier)
            .markDownloaded(share.id);
      } else if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo descargar el share.')),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo descargar el share.')),
        );
      }
    }
  }

  Future<void> _cancel(Share share) async {
    try {
      await ref.read(sharesControllerProvider.notifier).cancel(share.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cancelar el share.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sharesControllerProvider);
    final devices = ref.watch(devicesControllerProvider).devices;
    final localId = ref.watch(localDeviceIdProvider).valueOrNull;
    final colors = Theme.of(context).colorScheme;

    final List<Share> received;
    final List<Share> sent;
    if (localId == null) {
      received = state.shares;
      sent = const [];
    } else {
      received = state.shares
          .where((s) => s.senderDeviceId == null || s.senderDeviceId != localId)
          .toList();
      sent = state.shares
          .where((s) => s.senderDeviceId != null && s.senderDeviceId == localId)
          .toList();
    }
    final shares = _filter == _SharesFilter.received ? received : sent;

    String deviceName(Device? device) =>
        device?.name ?? 'Dispositivo desconocido';
    Device? deviceById(String? id) {
      if (id == null) return null;
      for (final d in devices) {
        if (d.id == id) return d;
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Row(
            children: [
              SegmentedButton<_SharesFilter>(
                segments: const [
                  ButtonSegment(
                    value: _SharesFilter.received,
                    label: Text('Recibidos'),
                  ),
                  ButtonSegment(
                    value: _SharesFilter.sent,
                    label: Text('Enviados'),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (s) =>
                    setState(() => _filter = s.first),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    ref.read(sharesControllerProvider.notifier).load(),
              ),
            ],
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: colors.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: state.isLoading && state.shares.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : shares.isEmpty
                  ? _SharesEmpty(filter: _filter)
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: shares.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final share = shares[index];
                        return _ShareTile(
                          share: share,
                          mine: _filter == _SharesFilter.sent,
                          subtitle: share.targetDeviceId == null
                              ? 'Todos los dispositivos'
                              : deviceName(deviceById(share.targetDeviceId)),
                          onAccept: (_filter == _SharesFilter.received &&
                                  share.isPending &&
                                  !share.isMineIfKnown(localId))
                              ? () => _accept(share)
                              : null,
                          onDownload: (share.status != ShareStatus.expired &&
                                  share.status != ShareStatus.downloaded &&
                                  _filter == _SharesFilter.received)
                              ? () => _download(share)
                              : null,
                          onCancel: (_filter == _SharesFilter.sent &&
                                  share.isPending)
                              ? () => _cancel(share)
                              : null,
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

extension on Share {
  /// true si el share es "mío" comparando contra el device local (o origen desconocido).
  bool isMineIfKnown(String? localId) =>
      localId != null && senderDeviceId == localId;
}

/// Tile de share con su estado y acciones.
class _ShareTile extends StatelessWidget {
  const _ShareTile({
    required this.share,
    required this.mine,
    required this.subtitle,
    this.onAccept,
    this.onDownload,
    this.onCancel,
  });

  final Share share;
  final bool mine;
  final String subtitle;
  final VoidCallback? onAccept;
  final VoidCallback? onDownload;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final file = share.file;

    return ListTile(
      leading: Icon(
        mine ? Icons.ios_share : Icons.file_download_outlined,
        color: colors.primary,
      ),
      title: Text(
        file?.name ?? 'Archivo',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$subtitle · ${share.statusXLabel}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onAccept != null)
            TextButton(onPressed: onAccept, child: const Text('Aceptar')),
          if (onDownload != null)
            IconButton(
              tooltip: 'Descargar',
              icon: const Icon(Icons.download),
              onPressed: onDownload,
            ),
          IconButton(
            icon: Icon(
              _statusIcon(share.status),
              color: _statusColor(share.status, colors),
            ),
            tooltip: share.statusXLabel,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }

  static IconData _statusIcon(ShareStatus status) => switch (status) {
    ShareStatus.created => Icons.schedule,
    ShareStatus.accepted => Icons.check_circle_outline,
    ShareStatus.downloaded => Icons.check_circle,
    ShareStatus.expired => Icons.cancel_outlined,
  };

  static Color _statusColor(ShareStatus status, ColorScheme colors) {
    final dark = colors.brightness == Brightness.dark;
    return switch (status) {
      ShareStatus.created => colors.onSurfaceVariant,
      ShareStatus.accepted =>
        dark ? DraculaPalette.cyan : DraculaPalette.alucardCyan,
      ShareStatus.downloaded =>
        dark ? DraculaPalette.green : DraculaPalette.alucardGreen,
      ShareStatus.expired => colors.error,
    };
  }
}

extension on Share {
  String get statusXLabel => status.label;
}

class _SharesEmpty extends StatelessWidget {
  const _SharesEmpty({required this.filter});

  final _SharesFilter filter;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final mine = filter == _SharesFilter.sent;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            mine ? Icons.ios_share : Icons.mark_email_read_outlined,
            size: 48,
            color: colors.outline,
          ),
          const SizedBox(height: 16),
          Text(
            mine ? 'Sin shares enviados' : 'Sin shares recibidos',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            mine
                ? 'Comparte un archivo con otro dispositivo para verlo aquí.'
                : 'Los archivos que te compartan aparecerán aquí.',
            style: textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}