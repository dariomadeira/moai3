import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/features/player/playback/channel_playback_helpers.dart';
import 'package:moai3/models/channel.dart';

typedef ReconnectPlayCallback = void Function({required bool isRetry});

enum ReconnectLogLevel { info, warn, error }

typedef ReconnectLogCallback = void Function(
  String message, {
  ReconnectLogLevel level,
});

class ReconnectionCoordinator {
  final int maxRetries;
  int retryCount = 0;
  int fallbackIndex = 0;
  Timer? _timer;
  bool isReconnecting = false;

  ReconnectionCoordinator({this.maxRetries = 3});

  void reset() {
    _timer?.cancel();
    _timer = null;
    retryCount = 0;
    isReconnecting = false;
  }

  void resetSources() {
    fallbackIndex = 0;
    reset();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  int playableCount(Channel channel) =>
      ChannelPlaybackHelpers.playableUrlCount(channel);

  void _log(
    ReconnectLogCallback? onLog,
    String message, {
    ReconnectLogLevel level = ReconnectLogLevel.info,
  }) {
    onLog?.call(message, level: level);
  }

  String _sourceLabel(Channel channel) =>
      ChannelPlaybackHelpers.playbackSourceLabel(channel, fallbackIndex);

  bool handleServerSkip(
    Channel channel, {
    ReconnectLogCallback? onLog,
  }) {
    final count = playableCount(channel);
    if (count <= 1 || fallbackIndex >= count - 1) {
      _log(
        onLog,
        'Skip manual: sin más servidores (${fallbackIndex + 1}/$count)',
        level: ReconnectLogLevel.warn,
      );
      return false;
    }
    fallbackIndex++;
    retryCount = 0;
    isReconnecting = true;
    _log(onLog, 'Skip manual → ${_sourceLabel(channel)}');
    return true;
  }

  /// Returns true if reconnect was scheduled, false if all options exhausted.
  bool scheduleReconnect({
    required Channel channel,
    required bool isDisposed,
    required ReconnectPlayCallback onPlay,
    required void Function(String message) onGiveUp,
    required void Function() onRetrying,
    void Function()? onStatsReconnecting,
    ReconnectLogCallback? onLog,
    String? reason,
  }) {
    if (isDisposed) return false;

    if (_timer?.isActive == true) {
      _log(onLog, 'Reconexión ya programada, ignorando duplicado');
      return true;
    }

    final count = playableCount(channel);
    if (count == 0) {
      isReconnecting = false;
      _log(
        onLog,
        'Sin URLs reproducibles',
        level: ReconnectLogLevel.error,
      );
      onGiveUp('player_error_no_urls'.tr());
      return false;
    }

    final reasonSuffix =
        reason != null && reason.isNotEmpty ? ' · $reason' : '';

    if (retryCount >= maxRetries) {
      if (fallbackIndex < count - 1) {
        fallbackIndex++;
        retryCount = 0;
        isReconnecting = true;
        _log(
          onLog,
          'Cambio de servidor → ${_sourceLabel(channel)}$reasonSuffix',
          level: ReconnectLogLevel.warn,
        );
        onRetrying();
        onStatsReconnecting?.call();
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 1), () {
          if (!isDisposed) onPlay(isRetry: true);
        });
        return true;
      }
      isReconnecting = false;
      _log(
        onLog,
        'Agotados $count servidores ($maxRetries reintentos c/u)$reasonSuffix',
        level: ReconnectLogLevel.error,
      );
      onGiveUp(
        '${'player_error_all_servers'.tr()}$reasonSuffix',
      );
      return false;
    }

    retryCount++;
    isReconnecting = true;
    _log(
      onLog,
      'Reintento $retryCount/$maxRetries · ${_sourceLabel(channel)}$reasonSuffix',
      level: ReconnectLogLevel.warn,
    );
    onRetrying();
    onStatsReconnecting?.call();

    final delaySeconds = 2 * retryCount;
    _timer?.cancel();
    _timer = Timer(Duration(seconds: delaySeconds), () {
      if (!isDisposed) onPlay(isRetry: true);
    });
    return true;
  }
}

