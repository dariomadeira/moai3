import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:flutter/services.dart';
import 'package:moai3/engine/engine_player_view.dart';
import 'package:moai3/engine/moai_engine_player.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_progress_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';

/// Pantalla completa de reproducción de películas para Smart TV.
/// Soporta controles nativos de D-Pad (Play/Pausa, Seek ±10s, OSD cinemático y persistencia).
class MoviePlayerScreen extends StatefulWidget {
  final MovieItem movie;
  final ResolvedPlayStream stream;
  final int? initialPositionSeconds;

  const MoviePlayerScreen({
    super.key,
    required this.movie,
    required this.stream,
    this.initialPositionSeconds,
  });

  @override
  State<MoviePlayerScreen> createState() => _MoviePlayerScreenState();
}

class _MoviePlayerScreenState extends State<MoviePlayerScreen> {
  late final MoaiEngineController _engine;
  final FocusNode _focusNode = FocusNode(debugLabel: 'movie_player_screen');

  bool _showOsd = true;
  Timer? _osdTimer;
  Timer? _positionTimer;
  Timer? _seekBadgeTimer;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  int _lastSavedSecond = 0;

  String? _seekBadgeText;
  bool _isPlaying = true;
  bool _isBuffering = true;
  bool _hasInitialSeeked = false;

  @override
  void initState() {
    super.initState();
    _engine = MoaiEngineController();
    _engine.addListener(_onEngineEvent);

    _initPlayer();
    _startPositionPolling();
    _resetOsdTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onEngineEvent() {
    if (!mounted) return;
    final event = _engine.event;
    final buffering = event.state == MoaiEngineState.buffering;
    final playing = event.isPlaying;

    if (buffering != _isBuffering || playing != _isPlaying) {
      setState(() {
        _isBuffering = buffering;
        _isPlaying = playing;
      });
    }

    // Si recibimos el primer cuadro y teníamos posición inicial guardada para reanudar
    if (!_hasInitialSeeked &&
        (event.firstFrameRendered || event.state == MoaiEngineState.ready)) {
      final startSec = widget.initialPositionSeconds ?? 0;
      if (startSec > 0) {
        _hasInitialSeeked = true;
        _engine.seekTo(Duration(seconds: startSec));
      }
    }
  }

  Future<void> _initPlayer() async {
    try {
      debugPrint('🎬 [MoviePlayer] Full Stream URL: ${widget.stream.streamUrl}');
      debugPrint('🎬 [MoviePlayer] Headers: ${widget.stream.headers}');
      await _engine.setMedia(MoaiMediaSpec(
        url: widget.stream.streamUrl,
        title: widget.movie.name,
        headers: widget.stream.headers,
      ));
    } catch (e) {
      debugPrint('⚠️ [MoviePlayer] Error al iniciar setMedia: $e');
    }
  }

  void _startPositionPolling() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 600), (_) async {
      if (!mounted) return;
      try {
        final pos = await _engine.getPosition();
        final dur = await _engine.getDuration();
        if (mounted) {
          setState(() {
            _currentPosition = pos;
            if (dur > Duration.zero) {
              _totalDuration = dur;
            }
          });

          // Guardar progreso cada ~10 segundos si cambió la posición
          final currentSec = pos.inSeconds;
          if ((currentSec - _lastSavedSecond).abs() >= 10 && _totalDuration > Duration.zero) {
            _lastSavedSecond = currentSec;
            unawaited(MovieProgressService.saveProgress(
              contentId: widget.movie.contentId,
              currentPosition: _currentPosition,
              totalDuration: _totalDuration,
            ));
          }
        }
      } catch (_) {}
    });
  }

  void _resetOsdTimer() {
    _osdTimer?.cancel();
    setState(() => _showOsd = true);
    _osdTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showOsd = false);
      }
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _engine.pause();
      setState(() {
        _isPlaying = false;
        _showOsd = true;
      });
      _osdTimer?.cancel(); // Si está pausado, mantenemos el OSD visible
    } else {
      _engine.play();
      setState(() => _isPlaying = true);
      _resetOsdTimer();
    }
  }

  void _seekBy(int seconds) async {
    _resetOsdTimer();
    final newPosMs = (_currentPosition.inMilliseconds + (seconds * 1000))
        .clamp(0, _totalDuration.inMilliseconds);
    final target = Duration(milliseconds: newPosMs);

    setState(() {
      _currentPosition = target;
      _seekBadgeText = seconds > 0 ? '+$seconds s' : '$seconds s';
    });

    unawaited(_engine.seekTo(target));

    _seekBadgeTimer?.cancel();
    _seekBadgeTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _seekBadgeText = null);
    });
  }

  Future<void> _handleBack() async {
    if (_showOsd && !_isBuffering && _isPlaying) {
      setState(() => _showOsd = false);
      return;
    }

    // Guardar progreso final al salir
    if (_totalDuration > Duration.zero) {
      await MovieProgressService.saveProgress(
        contentId: widget.movie.contentId,
        currentPosition: _currentPosition,
        totalDuration: _totalDuration,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _osdTimer?.cancel();
    _positionTimer?.cancel();
    _seekBadgeTimer?.cancel();
    _focusNode.dispose();

    // Guardar progreso al desmontar
    if (_totalDuration > Duration.zero) {
      MovieProgressService.saveProgress(
        contentId: widget.movie.contentId,
        currentPosition: _currentPosition,
        totalDuration: _totalDuration,
      );
    }

    _engine.removeListener(_onEngineEvent);
    _engine.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;

          if (TvKeyHandler.isActionKey(key)) {
            _togglePlayPause();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowLeft) {
            _seekBy(-10);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            _seekBy(10);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.arrowDown ||
              key == LogicalKeyboardKey.contextMenu) {
            _resetOsdTimer();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.escape ||
              key == LogicalKeyboardKey.backspace ||
              key == LogicalKeyboardKey.goBack) {
            _handleBack();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () {
            _focusNode.requestFocus();
            _resetOsdTimer();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Motor de video nativo en relación de aspecto cinematográfica completa
              EnginePlayerView(
                controller: _engine,
                fit: BoxFit.contain,
              ),

              // 2. Indicador de Buffering / Carga inicial
              if (_isBuffering)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          LocaleKeys.movies_loading_video.tr(),
                          style: MoaiText.body(
                            context,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 3. Badge flotante temporal de Seek (±10s)
              if (_seekBadgeText != null)
                Center(
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _seekBadgeText!.startsWith('+')
                                ? MoaiIcons.vodSkipForward
                                : MoaiIcons.vodSkipBack,
                            color: scheme.primary,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _seekBadgeText!,
                            style: MoaiText.display(
                              context,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 4. Capa OSD (HUD de cabecera y barra de progreso)
              AnimatedOpacity(
                opacity: _showOsd ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 240),
                child: IgnorePointer(
                  ignoring: !_showOsd,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Viñeta superior degradada
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 120,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.85),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Cabecera superior
                      Positioned(
                        top: 24,
                        left: 28,
                        right: 28,
                        child: Row(
                          children: [
                            TvBackPill(
                              onPressed: _handleBack,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                widget.movie.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MoaiText.display(
                                  context,
                                  fontSize: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TvMetaPill(
                              color: scheme.primaryContainer.withValues(alpha: 0.8),
                              foreground: scheme.onPrimaryContainer,
                              icon: MoaiIcons.vodQuality,
                              label: widget.stream.quality,
                            ),
                            const SizedBox(width: 8),
                            TvMetaPill(
                              color: Colors.white.withValues(alpha: 0.18),
                              foreground: Colors.white,
                              icon: MoaiIcons.vodAudio,
                              label: widget.stream.audioInfo,
                            ),
                            if (widget.stream.subtitleName != null) ...[
                              const SizedBox(width: 8),
                              TvMetaPill(
                                color: Colors.white.withValues(alpha: 0.18),
                                foreground: Colors.white,
                                icon: MoaiIcons.vodSubtitles,
                                label: widget.stream.subtitleName!,
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Viñeta inferior degradada
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 140,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.85),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Barra de progreso y tiempos inferior
                      Positioned(
                        bottom: 24,
                        left: 32,
                        right: 32,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Fila de tiempos
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _isPlaying
                                          ? MoaiIcons.vodPlay
                                          : MoaiIcons.vodPause,
                                      size: 16,
                                      color: scheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDuration(_currentPosition),
                                      style: MoaiText.body(
                                        context,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _formatDuration(_totalDuration),
                                  style: MoaiText.body(
                                    context,
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Barra de progreso interactiva / visual
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _totalDuration.inMilliseconds > 0
                                    ? (_currentPosition.inMilliseconds /
                                            _totalDuration.inMilliseconds)
                                        .clamp(0.0, 1.0)
                                    : 0.0,
                                minHeight: 6,
                                backgroundColor: Colors.white.withValues(alpha: 0.25),
                                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
