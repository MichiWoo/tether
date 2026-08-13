import 'file_item.dart';

/// Estados del share según el backend (`ShareStatus`).
enum ShareStatus { created, accepted, downloaded, expired }

extension ShareStatusX on ShareStatus {
  static ShareStatus fromWire(String value) => switch (value.toUpperCase()) {
    'ACCEPTED' => ShareStatus.accepted,
    'DOWNLOADED' => ShareStatus.downloaded,
    'EXPIRED' => ShareStatus.expired,
    _ => ShareStatus.created,
  };

  String get label => switch (this) {
    ShareStatus.created => 'Pendiente',
    ShareStatus.accepted => 'Aceptado',
    ShareStatus.downloaded => 'Descargado',
    ShareStatus.expired => 'Expirado',
  };
}

class Share {
  const Share({
    required this.id,
    required this.status,
    this.file,
    this.senderDeviceId,
    this.targetDeviceId,
    this.acceptedAt,
    this.downloadedAt,
    required this.expiresAt,
    required this.createdAt,
  });

  factory Share.fromJson(Map<String, dynamic> json) => Share(
        id: json['id'] as String,
        status: ShareStatusX.fromWire(json['status'] as String),
        file: json['file'] == null
            ? null
            : FileItem.fromJson(json['file'] as Map<String, dynamic>),
        senderDeviceId: json['senderDeviceId'] as String?,
        targetDeviceId: json['targetDeviceId'] as String?,
        acceptedAt: json['acceptedAt'] == null
            ? null
            : DateTime.parse(json['acceptedAt'] as String),
        downloadedAt: json['downloadedAt'] == null
            ? null
            : DateTime.parse(json['downloadedAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final ShareStatus status;
  final FileItem? file;
  final String? senderDeviceId;
  final String? targetDeviceId;
  final DateTime? acceptedAt;
  final DateTime? downloadedAt;
  final DateTime expiresAt;
  final DateTime createdAt;

  bool get isPending => status == ShareStatus.created;

  bool isMine(String localDeviceId) => senderDeviceId == localDeviceId;

  Share copyWith({ShareStatus? status, DateTime? acceptedAt, DateTime? downloadedAt}) =>
      Share(
        id: id,
        status: status ?? this.status,
        file: file,
        senderDeviceId: senderDeviceId,
        targetDeviceId: targetDeviceId,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        downloadedAt: downloadedAt ?? this.downloadedAt,
        expiresAt: expiresAt,
        createdAt: createdAt,
      );
}
