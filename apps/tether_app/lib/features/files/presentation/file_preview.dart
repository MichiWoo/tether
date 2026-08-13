import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../domain/file_item.dart';
import '../providers/files_provider.dart';

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
/// para los tipos no soportados. Usa componentes de shadcn_flutter.
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
    final theme = Theme.of(context);
    return SizedBox(
      width: 640,
      child: Card(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.foreground,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            switch (_kind) {
              FilePreviewKind.image =>
                _ImagePreview(url: widget.previewUrl),
              FilePreviewKind.text => _TextPreview(future: _textFuture),
              FilePreviewKind.unsupported => _MetadataView(file: widget.file),
            },
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Button.outline(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 480),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        width: double.infinity,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          final expected = progress.expectedTotalBytes;
          return SizedBox(
            height: 320,
            child: Center(
              child: CircularProgressIndicator(
                value: expected != null
                    ? progress.cumulativeBytesLoaded / expected
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: theme.colorScheme.mutedForeground,
                ),
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
    final theme = Theme.of(context);
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
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: theme.colorScheme.destructive,
                  ),
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
            color: theme.colorScheme.muted,
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
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icon, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        const Text(
          'Vista previa no disponible para este tipo de archivo.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _row(context, 'Tamaño', file.sizeLabel),
        _row(context, 'Tipo', file.mimeType ?? 'Desconocido'),
        _row(context, 'Subido', _formatDate(file.uploadedAt ?? file.createdAt)),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: theme.colorScheme.mutedForeground),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
