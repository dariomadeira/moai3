class DeviceRecord {
  final String deviceId;
  final String? userCode;
  final String? nickname;
  final String appVersion;
  final bool isActive;
  final String? blockReason;
  final bool online;
  final DateTime? lastSeen;
  final DateTime firstSeen;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? currentChannelId;
  final String? currentChannelName;

  DeviceRecord({
    required this.deviceId,
    this.userCode,
    this.nickname,
    required this.appVersion,
    required this.isActive,
    this.blockReason,
    required this.online,
    this.lastSeen,
    required this.firstSeen,
    required this.createdAt,
    required this.updatedAt,
    this.currentChannelId,
    this.currentChannelName,
  });

  factory DeviceRecord.fromJson(Map<String, dynamic> json) {
    return DeviceRecord(
      deviceId: json['device_id'] as String,
      userCode: json['user_code'] as String?,
      nickname: json['nickname'] as String?,
      appVersion: json['app_version'] as String? ?? 'unknown',
      isActive: json['is_active'] as bool? ?? true,
      blockReason: json['block_reason'] as String?,
      online: json['online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null 
          ? DateTime.tryParse(json['last_seen'].toString())?.toLocal() 
          : null,
      firstSeen: json['first_seen'] != null
          ? DateTime.tryParse(json['first_seen'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      currentChannelId: json['current_channel_id'] as String?,
      currentChannelName: json['current_channel_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'user_code': userCode,
      'nickname': nickname,
      'app_version': appVersion,
      'is_active': isActive,
      'block_reason': blockReason,
      'online': online,
      if (lastSeen != null) 'last_seen': lastSeen!.toUtc().toIso8601String(),
      if (currentChannelId != null) 'current_channel_id': currentChannelId,
      if (currentChannelName != null) 'current_channel_name': currentChannelName,
    };
  }
}

class DeviceIdentity {
  final String deviceId;
  final String appVersion;
  final DateTime firstLaunch;

  DeviceIdentity({
    required this.deviceId,
    required this.appVersion,
    required this.firstLaunch,
  });
}
