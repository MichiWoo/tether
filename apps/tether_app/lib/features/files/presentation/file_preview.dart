import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/file_item.dart';
import '../providers/files_provider.dart';

/// Abre el diálogo de vista previa de [file]. Resuelve la URL firmada inline
/// y delega en [FilePreviewDialog].
Future<void> showFilePreview(
  BuildContext context,
  WidgetRef ref,
  FileItem file,
) async {
  final String url;
  try {
    url = await ref.read(filesControllerProvider.notifier).getPreviewUrl(file.id);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar la vista previa.')),
      );
    }
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => FilePreviewDialog(file: file, previewUrl: url),
  );
}

/// Clasifica un archivo para decidir cómo previsualizarlo.
enum FilePreviewKind { image, text, unsupported }

FilePreviewKind previewKindOf(FileItem file) {
  final mime = file.mimeType ?? '';
  if (mime.startsWith('image/')) return FilePreviewKind.image;
  if (_isTextLike(mime)) return FilePreviewKind.text;
  return FilePreviewKind.unsupported;
}

bool _isTextLike(String mime) {
  if (mime.startsWith('text/')) return true;
  const textLike = {
    'application/json',
    'application/xml',
    'application/javascript',
    'application/x-javascript',
    'application/x-yaml',
    'application/x-sh',
    'application/x-ndjson',
    'application/graphql',
  };
  return textLike.contains(mime);
}

/// Diálogo de vista previa: muestra imágenes, contenido de texto o metadata
/// para los tipos no soportados.
class FilePreviewDialog extends ConsumerStatefulWidget {
  const FilePreviewDialog({
    super.key,
    required this.file,
    required this.previewUrl,
  });

  final FileItem file;
  final String previewUrl;

  @override
  ConsumerState<FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends ConsumerState<FilePreviewDialog> {
  late final FilePreviewKind _kind;
  late final Future<String> _textFuture;

  @override
  void initState() {
    super.initState();
    _kind = previewKindOf(widget.file);
    _textFuture = _kind == FilePreviewKind.text
        ? ref.read(uploadServiceProvider).fetchText(widget.previewUrl)
        : Future.value('');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.file.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: 640,
        child: switch (_kind) {
          FilePreviewKind.image => _ImagePreview(url: widget.previewUrl),
          FilePreviewKind.text => _TextPreview(future: _textFuture),
          FilePreviewKind.unsupported => _MetadataView(file: widget.file),
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 480),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        width: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            height: 320,
            child: Center(
              child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, size: 48, color: colors.outline),
                const SizedBox(height: 12),
                const Text('No se pudo cargar la imagen.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.future});

  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 160,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 40, color: colors.error),
                  const SizedBox(height: 8),
                  const Text('No se pudo cargar el contenido.'),
                ],
              ),
            ),
          );
        }
        return Container(
          constraints: const BoxConstraints(maxHeight: 420),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              snapshot.data ?? '',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        );
      },
    );
  }
}

class _MetadataView extends StatelessWidget {
  const _MetadataView({required this.file});

  final FileItem file;

  IconData get _icon {
    final mime = file.mimeType ?? '';
    if (mime.startsWith('video')) return Icons.videocam_outlined;
    if (mime.startsWith('audio')) return Icons.audiotrack_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icon, size: 56, color: colors.primary),
        const SizedBox(height: 12),
        Text(
          'Vista previa no disponible para este tipo de archivo.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _row(context, 'Tamaño', file.sizeLabel),
        _row(context, 'Tipo', file.mimeType ?? 'Desconocido'),
        _row(context, 'Subido', _formatDate(file.uploadedAt ?? file.createdAt)),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '${date.day}/${date.month}/${date.year} $hh:$mm';
}
