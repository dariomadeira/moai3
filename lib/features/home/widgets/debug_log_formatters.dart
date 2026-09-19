import 'package:moai3/config/app_config.dart';
import 'package:moai3/config/player_config.dart';
import 'package:moai3/features/player/playback/channel_playback_helpers.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/playback_stats_controller.dart';

class DebugLogFormatters {
  static String backendLabel(PlayerBackend backend) {
    switch (backend) {
      case PlayerBackend.none:
        return '—';
      case PlayerBackend.engineKotlin:
        return 'Motor Kotlin (ExoPlayer)';
      case PlayerBackend.legacyVideoPlayer:
        return 'video_player';
      case PlayerBackend.youtube:
        return 'YouTube';
    }
  }

  static String healthLabel(PlaybackHealth status) {
    switch (status) {
      case PlaybackHealth.idle:
        return 'Inactivo';
      case PlaybackHealth.playing:
        return 'Reproduciendo';
      case PlaybackHealth.buffering:
        return 'Buffering';
      case PlaybackHealth.reconnecting:
        return 'Reconectando';
      case PlaybackHealth.error:
        return 'Error';
    }
  }

  static String channelTypeLabel(Channel? channel) {
    if (channel == null) return '—';
    final urls = ChannelPlaybackHelpers.playableUrls(channel);
    final url = urls.isNotEmpty ? urls.first : channel.url;
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('youtube.com') ||
        lowerUrl.contains('youtu.be') ||
        lowerUrl.startsWith('youtube://') ||
        lowerUrl.startsWith('yt://')) {
      return 'YouTube';
    }
    if (url.endsWith('.m3u8')) return 'HLS';
    if (url.endsWith('.mpd')) return 'DASH';
    if (url.startsWith('daddylive://')) return 'DaddyLive';
    return 'Stream';
  }


  static String memoryLabel() =>
      'RAM ${PlayerConfig.totalRamMb} MB';

  static String debugStatusLabel() =>
      AppConfig.debugMode ? 'Activo' : 'Inactivo';
}




