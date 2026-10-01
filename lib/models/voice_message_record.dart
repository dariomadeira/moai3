/// Modelo que representa una nota de voz enviada o recibida en una sala de Watch Party (SPEC-37).
class VoiceMessageRecord {
  final String id;
  final String senderDeviceId;
  final String channelId;
  final String? channelName;
  final String audioUrl;
  final int durationMs;
  final DateTime createdAt;

  VoiceMessageRecord({
    required this.id,
    required this.senderDeviceId,
    required this.channelId,
    this.channelName,
    required this.audioUrl,
    required this.durationMs,
    required this.createdAt,
  });

  factory VoiceMessageRecord.fromJson(Map<String, dynamic> json) {
    return VoiceMessageRecord(
      id: json['id']?.toString() ?? '',
      senderDeviceId: json['sender_device_id'] as String? ?? '',
      channelId: json['channel_id'] as String? ?? '',
      channelName: json['channel_name'] as String?,
      audioUrl: json['audio_url'] as String? ?? '',
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_device_id': senderDeviceId,
      'channel_id': channelId,
      if (channelName != null) 'channel_name': channelName,
      'audio_url': audioUrl,
      'duration_ms': durationMs,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
