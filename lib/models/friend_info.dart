/// Modelo que representa la relación de amistad almacenada en la tabla `device_friends` (SPEC-36).
class Friendship {
  final String deviceId;
  final String friendDeviceId;
  final DateTime createdAt;

  Friendship({
    required this.deviceId,
    required this.friendDeviceId,
    required this.createdAt,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      deviceId: json['device_id'] as String,
      friendDeviceId: json['friend_device_id'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal() ??
              DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'friend_device_id': friendDeviceId,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

/// Modelo enriquecido que combina la amistad con los datos de presencia del amigo en `devices` (SPEC-36).
class FriendInfo {
  final String deviceId;
  final String userCode;
  final String? nickname;
  final bool isOnline;
  final DateTime? lastSeen;

  FriendInfo({
    required this.deviceId,
    required this.userCode,
    this.nickname,
    required this.isOnline,
    this.lastSeen,
  });

  factory FriendInfo.fromDeviceJson(Map<String, dynamic> json) {
    return FriendInfo(
      deviceId: json['device_id'] as String,
      userCode: json['user_code'] as String? ?? 'MOAI-????',
      nickname: json['nickname'] as String?,
      isOnline: json['online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'] as String)?.toLocal()
          : null,
    );
  }

  FriendInfo copyWith({
    String? deviceId,
    String? userCode,
    String? nickname,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return FriendInfo(
      deviceId: deviceId ?? this.deviceId,
      userCode: userCode ?? this.userCode,
      nickname: nickname ?? this.nickname,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

/// Configuración consolidada de Watch Party ("Miremos Juntos").
class WatchPartySettings {
  final bool enabled;
  final String userCode;
  final String? nickname;

  const WatchPartySettings({
    required this.enabled,
    required this.userCode,
    this.nickname,
  });
}
