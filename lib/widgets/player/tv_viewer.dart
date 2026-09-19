import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/engine/engine_player_view.dart';
import 'package:moai3/engine/moai_engine_player.dart';
import 'package:moai3/features/player/playback/channel_playback_helpers.dart';
import 'package:moai3/features/player/playback/playback_session_guard.dart';
import 'package:moai3/features/player/playback/reconnection_coordinator.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/debug_log_controller.dart';
import 'package:moai3/services/playback_stats_controller.dart';
import 'package:moai3/services/plugin_host_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/player/tv_viewer_focus_wrapper.dart';
import 'package:moai3/widgets/player/viewer_error_display.dart';

/// Visor TV usando el motor Kotlin nativo (ExoPlayer) con widget `Texture`.
class TvViewer extends StatefulWidget {
  final Channel? channel;
  final VoidCallback? onExitFullScreen;
  final bool isFullScreen;
  final ValueChanged<bool>? onFullScreenChanged;
  final VoidCallback? onRequestListFocus;
  final VoidCallback? onRequestUpFocus;
  final ValueChanged<bool>? onErrorStateChanged;
  final FocusNode? focusNode;
  final int reloadKey;
  final int serverSkipKey;

  const TvViewer({
    super.key,
    this.channel,
    this.onExitFullScreen,
    this.isFullScreen = false,
    this.onFullScreenChanged,
    this.onRequestListFocus,
    this.onRequestUpFocus,
    this.onErrorStateChanged,
    this.focusNode,
    this.reloadKey = 0,
    this.serverSkipKey = 0,
  });

  @override
  State<TvViewer> createState() => _TvViewerState();
}

class _TvViewerState extends State<TvViewer> with WidgetsBindingObserver {
  bool _isFullScreen = false;
  bool _isFocused = false;
  MoaiEngineController? _engine;
  bool _hasFirstFrame = false;
  bool _isBuffering = false;
  String? _errorMessage;
  bool _isDisposed = false;
  PlaybackStatsController? _stats;
  final ReconnectionCoordinator _reconnect = ReconnectionCoordinator();
  final PlaybackSessionGuard _session = PlaybackSessionGuard();

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _isDisposed) return;
    setState(fn);
  }

  void _log(String message, {ReconnectLogLevel level = ReconnectLogLevel.info}) {
    debugPrint('[TvViewer][${level.name}] $message');
    if (!mounted) return;
    final log = context.read<DebugLogController>();
    switch (level) {
      case ReconnectLogLevel.warn:
        log.logWarn(message);
      case ReconnectLogLevel.error:
        log.logError(message);
      case ReconnectLogLevel.info:
        log.logInfo(message);
    }
  }

  ReconnectLogCallback get _reconnectLogger =>
      (message, {level = ReconnectLogLevel.info}) =>
          _log(message, level: level);

  String get _currentUrl => widget.channel == null
      ? ''
      : ChannelPlaybackHelpers.currentUrl(
          widget.channel!,
          _reconnect.fallbackIndex,
        );

  PluginHostController? _pluginHost;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.channel != null) unawaited(_playChannel(widget.channel!));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_engine == null || _isDisposed) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _log('App en segundo plano: pausando reproductor y liberando buffers');
      unawaited(_engine?.pause());
    } else if (state == AppLifecycleState.resumed) {
      _log('App en primer plano: reanudando reproductor');
      unawaited(_engine?.play());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stats ??= context.read<PlaybackStatsController>();
    _pluginHost ??= context.read<PluginHostController>();
  }

  @override
  void didUpdateWidget(TvViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverSkipKey != widget.serverSkipKey) {
      if (widget.channel != null) {
        ChannelPlaybackHelpers.invalidateCache(_currentUrl);
        if (_reconnect.handleServerSkip(
          widget.channel!,
          onLog: _reconnectLogger,
        )) {
          _safeSetState(() => _errorMessage = null);
          unawaited(_playChannel(widget.channel!, isRetry: true));
        }
      }
    } else if (oldWidget.channel?.id != widget.channel?.id ||
        oldWidget.reloadKey != widget.reloadKey) {
      _reconnect.resetSources();
      if (widget.channel != null) {
        unawaited(_playChannel(widget.channel!));
      } else {
        unawaited(_disposeEngine().then((_) {
          _safeSetState(() {
            _hasFirstFrame = false;
          });
        }));
      }
    }
  }

  void _scheduleReconnect({String? reason}) {
    if (widget.channel == null) return;
    ChannelPlaybackHelpers.invalidateCache(_currentUrl);
    _reconnect.scheduleReconnect(
      channel: widget.channel!,
      isDisposed: _isDisposed,
      onLog: _reconnectLogger,
      reason: reason,
      onPlay: ({required isRetry}) =>
          unawaited(_playChannel(widget.channel!, isRetry: isRetry)),
      onGiveUp: (message) {
        _log(message, level: ReconnectLogLevel.error);
        _stats?.setError();
        _safeSetState(() {
          _errorMessage = message;
          widget.onErrorStateChanged?.call(true);
        });
      },
      onRetrying: () {
        _stats?.setReconnecting();
        _safeSetState(() {
          _errorMessage = null;
          widget.onErrorStateChanged?.call(false);
        });
      },
    );
    _safeSetState(() {});
  }

  void _onEngineEvent() {
    if (_isDisposed) return;
    final engine = _engine;
    if (engine == null) return;

    final event = engine.event;
    _hasFirstFrame = event.firstFrameRendered;
    _isBuffering = event.state == MoaiEngineState.buffering;
    final stats = _stats;

    if (event.videoWidth != null && event.videoWidth! > 0) {
      stats?.setVideoWidth(event.videoWidth!);
    }

    if (event.state == MoaiEngineState.error) {
      stats?.setError();
      final friendly = ChannelPlaybackHelpers.friendlyPlaybackError(
        event.errorCode,
        event.errorMessage,
      );
      _log(
        'Error motor: $friendly · code=${event.errorCode}',
        level: ReconnectLogLevel.warn,
      );
      _scheduleReconnect(reason: friendly);
      _safeSetState(() {});
      return;
    }

    if (event.isPlaying) {
      stats?.setPlaying();
    } else if (event.state == MoaiEngineState.buffering) {
      stats?.setBuffering();
    }
    _safeSetState(() {});
  }

  Future<void> _disposeEngine() async {
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      engine.removeListener(_onEngineEvent);
      await engine.dispose();
    }
  }

  Future<void> _playChannel(Channel channel, {bool isRetry = false}) async {
    final session = _session.begin();
    bool alive() => _session.isCurrent(session) && mounted && !_isDisposed;

    if (!isRetry) _reconnect.reset();
    _stats?.setFallbackIndex(_reconnect.fallbackIndex);
    await _disposeEngine();
    if (!alive()) return;

    _safeSetState(() {
      _hasFirstFrame = false;
      _isBuffering = false;
      if (_errorMessage != null && !isRetry) {
        _errorMessage = null;
        widget.onErrorStateChanged?.call(false);
      }
    });

    if (_currentUrl.isEmpty && !channel.isPluginChannel) {
      _scheduleReconnect(reason: 'URL vacía');
      return;
    }

    late final ResolvedPlayback resolved;
    try {
      resolved = await ChannelPlaybackHelpers.resolvePlayback(
        channel,
        _reconnect.fallbackIndex,
        service: _pluginHost?.service(),
      );
    } catch (e) {
      if (!alive()) return;
      _scheduleReconnect(reason: 'resolve: $e');
      return;
    }
    if (!alive()) return;
    if (resolved.url.isEmpty) {
      _scheduleReconnect(reason: 'URL vacía');
      return;
    }

    MoaiEngineController? newController;
    try {
      newController = MoaiEngineController();
      newController.addListener(_onEngineEvent);
      _engine = newController;

      await newController.setMedia(MoaiMediaSpec(
        url: resolved.url,
        title: channel.name,
        headers: resolved.headers,
        userAgent: ChannelPlaybackHelpers.defaultUserAgent,
        mimeType: resolved.mimeType,
        drmScheme: resolved.drmScheme,
        drmLicenseUri: resolved.drmLicenseUri,
      ));
      if (!alive() || _engine != newController) {
        newController.removeListener(_onEngineEvent);
        if (_engine == newController) _engine = null;
        await newController.dispose();
        return;
      }
      if (newController.event.hasError) {
        throw Exception(newController.event.errorMessage);
      }

      _stats?.setBackend(PlayerBackend.engineKotlin);
      _log(
        'Play · ${channel.name} · '
        '${ChannelPlaybackHelpers.playbackSourceLabel(channel, _reconnect.fallbackIndex)}',
      );
      await newController.play();
    } catch (e) {
      if (newController != null) {
        newController.removeListener(_onEngineEvent);
        if (_engine == newController) _engine = null;
        await newController.dispose();
      }
      if (!alive()) return;
      _scheduleReconnect(reason: '$e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isDisposed = true;
    _session.dispose();
    _reconnect.dispose();
    unawaited(_disposeEngine());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final effectiveFullScreen = widget.onFullScreenChanged != null
        ? widget.isFullScreen
        : _isFullScreen;

    final engine = _engine;
    Widget content = _errorMessage != null
        ? ViewerErrorDisplay(errorMessage: _errorMessage!)
        : (engine != null && engine.hasTexture && _hasFirstFrame)
            ? EnginePlayerView(
                controller: engine,
                showBuffering: _isBuffering,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: scheme.primary),
                  if (_reconnect.isReconnecting)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'player_reconnecting'.tr(
                          namedArgs: {
                            'retry': '${_reconnect.retryCount}',
                            'max': '${_reconnect.maxRetries}',
                            'current': '${_reconnect.fallbackIndex + 1}',
                            'total':
                                '${widget.channel != null ? _reconnect.playableCount(widget.channel!) : 0}',
                          },
                        ),
                        style: MoaiText.body(
                          context,
                          color: scheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              );

    Widget playerWidget = GestureDetector(
      onTap: () {
        if (widget.onFullScreenChanged != null) {
          widget.onFullScreenChanged!(!widget.isFullScreen);
        } else {
          setState(() => _isFullScreen = !_isFullScreen);
          if (!_isFullScreen) widget.onExitFullScreen?.call();
        }
      },
      child: effectiveFullScreen
          ? ColoredBox(color: scheme.surface, child: content)
          : AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isFocused ? scheme.primary : Colors.transparent,
                  width: 4,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: content,
              ),
            ),
    );

    if (!effectiveFullScreen) {
      playerWidget = AspectRatio(aspectRatio: 16 / 9, child: playerWidget);
    }

    return TvViewerFocusWrapper(
      focusNode: widget.focusNode,
      effectiveFullScreen: effectiveFullScreen,
      onFullScreenChanged: widget.onFullScreenChanged != null
          ? (full) => widget.onFullScreenChanged!(full)
          : null,
      onExitFullScreen: () {
        setState(() => _isFullScreen = false);
        widget.onExitFullScreen?.call();
      },
      onRequestListFocus: widget.onRequestListFocus,
      onRequestUpFocus: widget.onRequestUpFocus,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: playerWidget,
    );
  }
}