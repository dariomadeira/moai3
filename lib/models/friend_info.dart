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
  final bool _rawIsOnline;
  final DateTime? lastSeen;
  final String? currentChannelId;
  final String? currentChannelName;

  FriendInfo({
    required this.deviceId,
    required this.userCode,
    this.nickname,
    required bool isOnline,
    this.lastSeen,
    this.currentChannelId,
    this.currentChannelName,
  }) : _rawIsOnline = isOnline;

  /// Retorna true si el estado en BD es online Y su `lastSeen` es reciente (no stale).
  bool get isOnline {
    if (!_rawIsOnline) return false;
    if (lastSeen == null) return true;
    final diffSeconds = DateTime.now().difference(lastSeen!).inSeconds.abs();
    // Si han pasado más de 60 segundos desde el último latido y está dentro del rango reciente (< 24h) -> offline por inactividad
    if (diffSeconds > 60 && diffSeconds < 86400) {
      return false;
    }
    return true;
  }

  /// Retorna el nombre del canal que el amigo está viendo, o null si está offline o es un canal de adultos.
  String? get displayChannelName {
    if (!isOnline) return null;
    final name = currentChannelName?.trim();
    if (name == null || name.isEmpty) return null;

    final lower = name.toLowerCase();
    if (lower.contains('18+') ||
        lower.contains('+18') ||
        lower.contains('adult') ||
        lower.contains('xxx') ||
        lower.contains('playboy') ||
        lower.contains('venus') ||
        lower.contains('erotic') ||
        lower.contains('erotico')) {
      return null;
    }
    return name;
  }

  factory FriendInfo.fromDeviceJson(Map<String, dynamic> json) {
    return FriendInfo(
      deviceId: json['device_id'] as String,
      userCode: json['user_code'] as String? ?? 'MOAI-????',
      nickname: json['nickname'] as String?,
      isOnline: json['online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'] as String)?.toLocal()
          : null,
      currentChannelId: json['current_channel_id'] as String?,
      currentChannelName: json['current_channel_name'] as String?,
    );
  }

  /// Comprueba si este amigo está mirando el mismo canal (SPEC-37).
  /// Primero intenta coincidencia exacta de ID (ej. 'plugin:ar:tyc_sports').
  /// Si no coincide el ID pero ambos tienen nombre, compara nombres normalizados (ej. 'ESPN').
  bool isWatchingSameChannel(String? myChannelId, [String? myChannelName]) {
    if (!isOnline) return false;
    if (currentChannelId == null || currentChannelId!.trim().isEmpty) return false;

    // 1. Coincidencia exacta de ID
    if (myChannelId != null && myChannelId.isNotEmpty && currentChannelId == myChannelId) {
      return true;
    }

    // 2. Coincidencia por nombre normalizado (Cross-plugin fallback)
    if (myChannelName != null && currentChannelName != null) {
      final a = _normalizeChannelName(currentChannelName!);
      final b = _normalizeChannelName(myChannelName);
      if (a.isNotEmpty && a == b) {
        return true;
      }
    }

    return false;
  }

  static String _normalizeChannelName(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\b(hd|fhd|sd|4k|argentina|arg)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  FriendInfo copyWith({
    String? deviceId,
    String? userCode,
    String? nickname,
    bool? isOnline,
    DateTime? lastSeen,
    String? currentChannelId,
    String? currentChannelName,
  }) {
    return FriendInfo(
      deviceId: deviceId ?? this.deviceId,
      userCode: userCode ?? this.userCode,
      nickname: nickname ?? this.nickname,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      currentChannelId: currentChannelId ?? this.currentChannelId,
      currentChannelName: currentChannelName ?? this.currentChannelName,
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
