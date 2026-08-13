/// Estados del archivo según el backend (`FileStatus`).
enum FileStatus { pending, uploaded }

extension FileStatusX on FileStatus {
  static FileStatus fromWire(String value) => switch (value.toUpperCase()) {
    'UPLOADED' => FileStatus.uploaded,
    _ => FileStatus.pending,
  };
}

class FileItem {
  const FileItem({
    required this.id,
    required this.name,
    required this.size,
    this.mimeType,
    required this.status,
    this.uploadedAt,
    required this.createdAt,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) => FileItem(
        id: json['id'] as String,
        name: json['name'] as String,
        size: json['size'] as int,
        mimeType: json['mimeType'] as String?,
        status: FileStatusX.fromWire(json['status'] as String),
        uploadedAt: json['uploadedAt'] == null
            ? null
            : DateTime.parse(json['uploadedAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String name;
  final int size;
  final String? mimeType;
  final FileStatus status;
  final DateTime? uploadedAt;
  final DateTime createdAt;

  bool get isUploaded => status == FileStatus.uploaded;

  /// Tamaño formateado (KB, MB, GB).
  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
