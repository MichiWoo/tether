import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../devices/domain/device.dart';
import '../../devices/providers/devices_provider.dart';
import '../../../core/theme/dracula_palette.dart';
import '../domain/file_item.dart';
import '../providers/downloads_provider.dart';
import '../providers/files_provider.dart';
import '../providers/shares_provider.dart';
import 'file_preview.dart';
import 'shares_section.dart';

/// Pantalla Archivos: sube/descarga archivos del cloud y los comparte entre
/// los dispositivos del usuario.
class FilesScreen extends StatelessWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DownloadsSection(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                dividerColor: Colors.transparent,
                labelColor: colors.primary,
                unselectedLabelColor: colors.onSurfaceVariant,
                indicatorColor: colors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: 'Mis archivos'),
                  Tab(text: 'Compartidos'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          const Expanded(
            child: TabBarView(
              children: [_FilesTab(), SharesTab()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pestaña "Mis archivos": drop zone, subidas con progreso y lista.
class _FilesTab extends ConsumerStatefulWidget {
  const _FilesTab();

  @override
  ConsumerState<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends ConsumerState<_FilesTab> {
  bool _dragging = false;

  Future<void> _pickFiles() async {
    final files = await openFiles(
      acceptedTypeGroups: const [XTypeGroup(label: 'Archivos')],
    );
    final paths = files.map((f) => f.path).where((p) => p.isNotEmpty).toList();
    if (paths.isEmpty) return;
    await ref.read(filesControllerProvider.notifier).uploadPaths(paths);
  }

  void _onDrop(DropDoneDetails details) {
    final paths = details.files
        .map((f) => f.path)
        .where((p) => p.isNotEmpty)
        .toList();
    if (paths.isEmpty) return;
    ref.read(filesControllerProvider.notifier).uploadPaths(paths);
  }

  Future<void> _download(FileItem file) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = await ref
        .read(filesControllerProvider.notifier)
        .getDownloadUrl(file.id);
    if (!mounted) return;
    final location = await getSaveLocation(suggestedName: file.name);
    if (location == null) return;

    final ok = await ref.read(downloadsControllerProvider.notifier).start(
          name: file.name,
          url: url,
          savePath: location.path,
        );
    if (!ok && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo descargar el archivo.')),
      );
    }
  }

  Future<void> _delete(FileItem file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text('¿Eliminar "${file.name}" del cloud?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(filesControllerProvider.notifier).delete(file.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el archivo.')),
        );
      }
    }
  }

  void _share(FileItem file) {
    showDialog<void>(
      context: context,
      builder: (context) => _ShareDialog(file: file),
    );
  }

  void _preview(FileItem file) => showFilePreview(context, ref, file);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(filesControllerProvider);

    return DropTarget(
      enable: true,
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        _onDrop(details);
      },
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DropZone(onTap: _pickFiles, dragging: _dragging),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: _ErrorBanner(message: state.error!),
                ),
              if (state.uploads.isNotEmpty) _buildUploads(state.uploads),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Row(
                  children: [
                    Text(
                      'Tus archivos',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (state.files.isNotEmpty)
                      Text(
                        '${state.files.length}',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Actualizar',
                      icon: const Icon(Icons.refresh),
                      onPressed: () =>
                          ref.read(filesControllerProvider.notifier).load(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.isLoading && state.files.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : state.files.isEmpty
                        ? const _FilesEmpty()
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: state.files.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final file = state.files[index];
                              return _FileTile(
                                file: file,
                                onPreview: file.isUploaded
                                    ? () => _preview(file)
                                    : null,
                                onDownload: file.isUploaded
                                    ? () => _download(file)
                                    : null,
                                onShare: file.isUploaded
                                    ? () => _share(file)
                                    : null,
                                onDelete: () => _delete(file),
                              );
                            },
                          ),
              ),
            ],
          ),
          // Overlay visual mientras se arrastra un archivo sobre la ventana.
          if (_dragging) _buildDropOverlay(),
        ],
      ),
    );
  }

  Widget _buildUploads(List<UploadTask> uploads) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final task in uploads) _UploadTile(task: task),
        ],
      ),
    );
  }

  Widget _buildDropOverlay() {
    final colors = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: Container(
        color: colors.primary.withOpacity(0.08),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.primary, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.file_download_outlined, size: 40, color: colors.primary),
                const SizedBox(height: 12),
                Text(
                  'Suelta para subir',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zona de arrastrar + botón "Seleccionar archivos".
class _DropZone extends StatelessWidget {
  const _DropZone({required this.onTap, required this.dragging});

  final VoidCallback onTap;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Material(
        color: dragging ? colors.primaryContainer : colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Icon(Icons.cloud_upload_outlined, size: 36, color: colors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Arrastra archivos aquí', style: textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        'Se suben automáticamente a tu almacenamiento.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: onTap,
                  child: const Text('Seleccionar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tile de archivo con acciones (descargar / compartir / eliminar).
class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    this.onPreview,
    this.onDownload,
    this.onShare,
    required this.onDelete,
  });

  final FileItem file;
  final VoidCallback? onPreview;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;
  final VoidCallback onDelete;

  IconData get _icon {
    final mime = file.mimeType ?? '';
    if (mime.startsWith('image')) return Icons.image_outlined;
    if (mime.startsWith('video')) return Icons.videocam_outlined;
    if (mime.startsWith('audio')) return Icons.audiotrack_outlined;
    if (mime.startsWith('text')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: Icon(_icon, color: colors.primary),
      onTap: onPreview,
      title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${file.sizeLabel} · ${_formatDate(file.createdAt)}',
            style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (!file.isUploaded)
            Text(
              'Pendiente',
              style: textTheme.labelSmall?.copyWith(color: colors.error),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onShare != null)
            IconButton(
              tooltip: 'Compartir',
              icon: const Icon(Icons.ios_share),
              onPressed: onShare,
            ),
          if (onDownload != null)
            IconButton(
              tooltip: 'Descargar',
              icon: const Icon(Icons.download),
              onPressed: onDownload,
            ),
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Tile de subida con barra de progreso y opción de descartar errores.
class _UploadTile extends ConsumerWidget {
  const _UploadTile({required this.task});

  final UploadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final error = task.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: error != null
              ? colors.errorContainer.withOpacity(0.4)
              : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              error != null
                  ? Icons.error_outline
                  : Icons.cloud_upload_outlined,
              color: error != null ? colors.error : colors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  if (error != null)
                    Text(error, style: textTheme.bodySmall?.copyWith(color: colors.error))
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: task.progress,
                        minHeight: 6,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Descartar',
              icon: const Icon(Icons.close),
              onPressed: () =>
                  ref
                      .read(filesControllerProvider.notifier)
                      .dismissUpload(task.id),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cola de descargas activas: una barra de progreso por archivo.
/// Se muestra sobre el contenido para verse desde cualquier pestaña.
class _DownloadsSection extends ConsumerWidget {
  const _DownloadsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsControllerProvider).downloads;
    if (downloads.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final task in downloads) _DownloadTile(task: task),
        ],
      ),
    );
  }
}

/// Tile de descarga con barra de progreso y botón para cancelar/descartar.
class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.task});

  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final error = task.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: error != null
              ? colors.errorContainer.withOpacity(0.4)
              : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              error != null ? Icons.error_outline : Icons.download_outlined,
              color: error != null ? colors.error : colors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  if (error != null)
                    Text(
                      error,
                      style: textTheme.bodySmall?.copyWith(color: colors.error),
                    )
                  else
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: task.progress,
                        minHeight: 6,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: error != null ? 'Descartar' : 'Cancelar',
              icon: const Icon(Icons.close),
              onPressed: () {
                final controller = ref.read(downloadsControllerProvider.notifier);
                if (error != null) {
                  controller.dismiss(task.id);
                } else {
                  controller.cancel(task.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para elegir el destino de un share: todos los dispositivos o uno.
class _ShareDialog extends ConsumerWidget {  const _ShareDialog({required this.file});

  final FileItem file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesControllerProvider).devices;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    Future<void> share({String? targetDeviceId}) async {
      try {
        await ref.read(sharesControllerProvider.notifier).create(
          fileId: file.id,
          targetDeviceId: targetDeviceId,
        );
        if (context.mounted) Navigator.pop(context);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo compartir el archivo.')),
          );
        }
      }
    }

    return AlertDialog(
      title: Text('Compartir "${file.name}"'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Todos los dispositivos'),
              subtitle: Text(
                'Notifica a todos tus dispositivos',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              onTap: () => share(),
            ),
            if (devices.isNotEmpty) ...[
              const Divider(height: 1),
              for (final device in devices)
                ListTile(
                  leading: Icon(_deviceIcon(device.platform)),
                  title: Text(device.name),
                  subtitle: Text(
                    device.isOnline ? 'En línea' : 'Desconectado',
                    style: textTheme.bodySmall?.copyWith(
                      color: device.isOnline
                          ? StatusColors.success(context)
                          : colors.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => share(targetDeviceId: device.id),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

IconData _deviceIcon(DevicePlatform platform) => switch (platform) {
  DevicePlatform.macos => Icons.laptop_mac_outlined,
  DevicePlatform.windows => Icons.laptop_windows_outlined,
  DevicePlatform.linux => Icons.laptop_outlined,
  DevicePlatform.ios => Icons.phone_iphone,
  DevicePlatform.android => Icons.phone_android,
  DevicePlatform.web => Icons.language,
};

class _FilesEmpty extends StatelessWidget {
  const _FilesEmpty();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined, size: 48, color: colors.outline),
          const SizedBox(height: 16),
          Text('Sin archivos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Arrastra archivos a la ventana para empezar.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
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
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final sameDay = now.year == date.year &&
      now.month == date.month &&
      now.day == date.day;
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  if (sameDay) return 'Hoy $hh:$mm';
  return '${date.day}/${date.month}/${date.year} $hh:$mm';
}