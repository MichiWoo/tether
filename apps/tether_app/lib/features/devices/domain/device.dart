/// Plataformas soportadas (reflejan el enum del backend).
enum DevicePlatform { ios, android, windows, linux, macos, web }

extension DevicePlatformX on DevicePlatform {
  String get wire {
    switch (this) {
      case DevicePlatform.ios:
        return 'IOS';
      case DevicePlatform.android:
        return 'ANDROID';
      case DevicePlatform.windows:
        return 'WINDOWS';
      case DevicePlatform.linux:
        return 'LINUX';
      case DevicePlatform.macos:
        return 'MACOS';
      case DevicePlatform.web:
        return 'WEB';
    }
  }

  String get label {
    switch (this) {
      case DevicePlatform.ios:
        return 'iOS';
      case DevicePlatform.android:
        return 'Android';
      case DevicePlatform.windows:
        return 'Windows';
      case DevicePlatform.linux:
        return 'Linux';
      case DevicePlatform.macos:
        return 'macOS';
      case DevicePlatform.web:
        return 'Web';
    }
  }

  static DevicePlatform fromWire(String value) {
    switch (value.toUpperCase()) {
      case 'IOS':
        return DevicePlatform.ios;
      case 'ANDROID':
        return DevicePlatform.android;
      case 'WINDOWS':
        return DevicePlatform.windows;
      case 'LINUX':
        return DevicePlatform.linux;
      case 'MACOS':
        return DevicePlatform.macos;
      case 'WEB':
        return DevicePlatform.web;
    }
    return DevicePlatform.web;
  }
}

class Device {
  const Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.isOnline,
    this.lastSeenAt,
    required this.createdAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) => Device(
        id: json['id'] as String,
        name: json['name'] as String,
        platform: DevicePlatformX.fromWire(json['platform'] as String),
        isOnline: json['isOnline'] as bool,
        lastSeenAt: json['lastSeenAt'] == null
            ? null
            : DateTime.parse(json['lastSeenAt'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String name;
  final DevicePlatform platform;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final DateTime createdAt;

  Device copyWith({bool? isOnline, DateTime? lastSeenAt, String? name}) => Device(
        id: id,
        name: name ?? this.name,
        platform: platform,
        isOnline: isOnline ?? this.isOnline,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        createdAt: createdAt,
      );
}
