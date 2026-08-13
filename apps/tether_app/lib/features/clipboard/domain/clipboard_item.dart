class ClipboardItem {
  const ClipboardItem({
    required this.id,
    required this.content,
    this.sourceDeviceId,
    this.sourceDeviceName,
    required this.createdAt,
  });

  factory ClipboardItem.fromJson(Map<String, dynamic> json) => ClipboardItem(
        id: json['id'] as String,
        content: json['content'] as String,
        sourceDeviceId: json['sourceDeviceId'] as String?,
        sourceDeviceName: json['sourceDeviceName'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String content;
  final String? sourceDeviceId;
  final String? sourceDeviceName;
  final DateTime createdAt;
}
