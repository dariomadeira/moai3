import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/config/app_config.dart';
import 'package:moai3/config/app_info.dart';
import 'package:moai3/features/player/playback/channel_playback_helpers.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/playback_stats_controller.dart';

class DebugLogFormatters {
  static String backendLabel(PlayerBackend backend) {
    switch (backend) {
      case PlayerBackend.none:
        return '—';
      case PlayerBackend.engineKotlin:
        return LocaleKeys.debug_backend_kotlin.tr();
    }
  }

  static String healthLabel(PlaybackHealth status) {
    switch (status) {
      case PlaybackHealth.idle:
        return LocaleKeys.debug_status_inactive.tr();
      case PlaybackHealth.playing:
        return LocaleKeys.debug_health_playing.tr();
      case PlaybackHealth.buffering:
        return LocaleKeys.debug_health_buffering.tr();
      case PlaybackHealth.reconnecting:
        return LocaleKeys.debug_health_reconnecting.tr();
      case PlaybackHealth.error:
        return LocaleKeys.debug_health_error.tr();
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
      return LocaleKeys.debug_backend_youtube.tr();
    }
    if (url.endsWith('.m3u8')) return LocaleKeys.debug_type_hls.tr();
    if (url.endsWith('.mpd')) return LocaleKeys.debug_type_dash.tr();
    if (url.startsWith('daddylive://')) return LocaleKeys.debug_type_daddylive.tr();
    return LocaleKeys.debug_type_stream.tr();
  }


  static String memoryLabel() =>
      LocaleKeys.debug_memory.tr(namedArgs: {'mb': '${AppInfo.totalRamMb}'});

  static String debugStatusLabel() =>
      AppConfig.debugMode
          ? LocaleKeys.common_active.tr()
          : LocaleKeys.debug_status_inactive.tr();
}




