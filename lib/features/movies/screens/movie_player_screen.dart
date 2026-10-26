import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/engine/engine_player_view.dart';
import 'package:moai3/engine/moai_engine_player.dart';
import 'package:moai3/features/movies/movie_player_format.dart';
import 'package:moai3/features/movies/titan_playback_bridge.dart';
import 'package:moai3/features/movies/widgets/movie_player_osd.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_library.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:provider/provider.dart';

/// Pantalla completa de reproducción de películas para Smart TV.
///
/// Controles: OK pausa/reanuda; ←/→ buscan (mantenidas aceleran) y el salto
/// se hace una sola vez al confirmar con OK o al soltar; atrás cancela la
/// búsqueda, esconde la interfaz o sale. Si el video falla, OK reintenta
/// desde el mismo punto.
class MoviePlayerScreen extends StatefulWidget {
  final MovieItem movie;
  final ResolvedPlayStream stream;
  final int? initialPositionSeconds;

  /// Guarda por dónde va para retomar. Los tráileres se ven de una vez:
  /// van sin progreso.
  final bool saveProgress;

  const MoviePlayerScreen({
    super.key,
    required this.movie,
    required this.stream,
    this.initialPositionSeconds,
    this.saveProgress = true,
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

  /// Por dónde va: la barra lo escucha sola, así el sondeo no reconstruye
  /// toda la pantalla.
  final ValueNotifier<Duration> _position = ValueNotifier(Duration.zero);
  Duration get _currentPosition => _position.value;
  set _currentPosition(Duration value) => _position.value = value;

  Duration _totalDuration = Duration.zero;
  int _lastSavedSecond = 0;

  bool _isPlaying = true;
  bool _isBuffering = true;
  bool _hasError = false;

  /// Posición a la que saltar cuando el video esté listo (retomar o
  /// reintentar). Se usa una sola vez.
  Duration? _startAt;

  /// Búsqueda en curso: destino elegido con ←/→, todavía sin saltar.
  Duration? _scrubTarget;
  int _scrubRepeats = 0;

  /// Se salta solo si se deja de buscar un momento.
  Timer? _scrubCommitTimer;
  static const _scrubCommitDelay = Duration(milliseconds: 900);

  /// Después de saltar, la posición del motor tarda en llegar: hasta esta
  /// hora no se pisa la barra con la posición vieja.
  DateTime? _seekSettlesAt;

  /// Idioma pedido al motor según Ajustes › Películas y series.
  String? _preferredAudio;

  /// Audios del stream según el motor (vacío hasta que los conoce).
  List<MoaiAudioTrack> _audioTracks = const [];

  /// Subtítulo elegido según Ajustes (null: apagados o no hay ese idioma).
  VodSubtitleOption? _subtitle;

  /// Texto del subtítulo de este momento, según el motor.
  String _subtitleText = '';

  /// Chip de audio: el que suena según el motor; mientras no se sabe, el
  /// pedido (si la película lo trae) o el primero de la API.
  String get _audioLabel {
    for (final track in _audioTracks) {
      if (track.selected) {
        return audioLanguageLabel(
          track.language ?? '',
          trackLabel: track.label,
        );
      }
    }
    final preferred = _preferredAudio;
    final available = widget.stream.audioInfo
        .split(',')
        .map(audioLanguageCode)
        .toSet();
    if (preferred != null && available.contains(preferred)) {
      return audioLanguageLabel(preferred);
    }
    return audioLanguageLabel(widget.stream.audioInfo);
  }

  @override
  void initState() {
    super.initState();
    final start = widget.initialPositionSeconds ?? 0;
    if (start > 0) _startAt = Duration(seconds: start);
    final settings = context.read<TvSettingsProvider?>();
    _preferredAudio = preferredAudioCode(
      settings?.movieAudioLanguage ?? MovieAudioLanguage.defaultValue,
      widget.stream.audioInfo,
    );
    _subtitle = pickSubtitle(
      settings?.movieSubtitleLanguage ?? MovieSubtitleLanguage.defaultValue,
      widget.stream.subtitles,
    );
    // Un corte a mitad de la película espera 90 s antes del error.
    _engine = MoaiEngineController(
      rebufferTimeout: const Duration(seconds: 90),
    );
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
    final failed = event.state == MoaiEngineState.error;

    if (buffering != _isBuffering ||
        playing != _isPlaying ||
        failed != _hasError ||
        !identical(_engine.audioTracks, _audioTracks) ||
        _engine.subtitleText != _subtitleText) {
      setState(() {
        _isBuffering = buffering;
        _isPlaying = playing;
        _hasError = failed;
        _audioTracks = _engine.audioTracks;
        _subtitleText = _engine.subtitleText;
      });
    }
    if (failed) {
      _osdTimer?.cancel();
      _cancelScrub();
      debugPrint('⚠️ [MoviePlayer] Error del motor: ${event.errorMessage}');
    }

    _titan.onEngineEvent(event);

    // Primer cuadro: si había que retomar o reintentar, saltar ahí.
    final ready =
        event.firstFrameRendered || event.state == MoaiEngineState.ready;
    final start = _startAt;
    if (start != null && ready) {
      _startAt = null;
      _seekTo(start);
    }
    if (ready) _playbackStarted = true;

    if (event.state == MoaiEngineState.ended) unawaited(_onPlaybackEnded());
  }

  /// Lo que se le cuenta a Titan Ranger (si el video viene de su proxy).
  late final TitanPlaybackBridge _titan = TitanPlaybackBridge(
    streamUrl: widget.stream.streamUrl,
    programName: widget.movie.contentId,
  );

  Future<void> _initPlayer() async {
    try {
      // Las cabeceras llevan PORTAL_KEY y userId: sólo en debug.
      if (kDebugMode) {
        debugPrint(
          '🎬 [MoviePlayer] Full Stream URL: ${widget.stream.streamUrl}',
        );
        debugPrint('🎬 [MoviePlayer] Headers: ${widget.stream.headers}');
      }
      await _engine.setMedia(
        MoaiMediaSpec(
          url: widget.stream.streamUrl,
          title: widget.movie.displayName,
          headers: widget.stream.headers,
          preferredAudioLanguage: _preferredAudio,
          subtitleUrl: _subtitle?.url,
          subtitleMimeType: _subtitle?.mimeType,
          subtitleLanguage: _subtitle?.language,
        ),
      );
    } catch (e) {
      debugPrint('⚠️ [MoviePlayer] Error al iniciar setMedia: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  /// OK con el error en pantalla: vuelve a cargar y retoma donde estaba.
  void _retry() {
    // Si falló justo después de un salto (o al retomar), no repetirlo:
    // volver a donde estaba antes (al principio, si fue al retomar).
    final seekFailed =
        _lastSeekAt != null &&
        DateTime.now().difference(_lastSeekAt!) < const Duration(seconds: 60);
    final resumeAt = seekFailed ? _beforeLastSeek : _currentPosition;
    _lastSeekAt = null;
    _startAt = resumeAt > Duration.zero ? resumeAt : null;
    _currentPosition = resumeAt;
    _titan.reset();
    setState(() {
      _hasError = false;
      _isBuffering = true;
    });
    _resetOsdTimer();
    _initPlayer();
  }

  void _startPositionPolling() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 600), (
      _,
    ) async {
      if (!mounted) return;
      try {
        // Una sola llamada al motor por vuelta.
        final status = await _engine.getStatus();
        final pos = status.position;
        _titan.onPosition(pos, status.buffered);
        if (mounted) {
          final settling =
              _seekSettlesAt != null &&
              DateTime.now().isBefore(_seekSettlesAt!);
          if (!settling) _currentPosition = pos;
          // La duración casi nunca cambia: sólo entonces se reconstruye.
          final dur = status.duration;
          if (dur > Duration.zero && dur != _totalDuration) {
            setState(() => _totalDuration = dur);
          }

          // Guardar progreso cada ~10 segundos si cambió la posición
          final currentSec = _currentPosition.inSeconds;
          if ((currentSec - _lastSavedSecond).abs() >= 10 && _canSaveProgress) {
            _lastSavedSecond = currentSec;
            unawaited(_saveProgress());
          }
        }
      } catch (_) {}
    });
  }

  /// Pausado por la persona (OK): ahí la interfaz queda visible.
  bool _userPaused = false;

  /// Muestra la interfaz y la esconde a los 4 s. Si en ese momento está
  /// cargando (al arrancar, tras un salto o al retomar), vuelve a probar en
  /// vez de dejarla fija; sólo queda visible con pausa, búsqueda o error.
  void _resetOsdTimer() {
    _osdTimer?.cancel();
    setState(() => _showOsd = true);
    _scheduleOsdHide(const Duration(seconds: 4));
  }

  void _scheduleOsdHide(Duration after) {
    _osdTimer?.cancel();
    _osdTimer = Timer(after, () {
      if (!mounted || !_showOsd) return;
      if (_userPaused || _scrubTarget != null || _hasError) return;
      if (_isPlaying && !_isBuffering) {
        setState(() => _showOsd = false);
      } else {
        _scheduleOsdHide(const Duration(seconds: 1));
      }
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _engine.pause();
      _titan.onPause();
      setState(() {
        _isPlaying = false;
        _userPaused = true;
        _showOsd = true;
      });
      _osdTimer?.cancel(); // Si está pausado, mantenemos el OSD visible
    } else {
      _engine.play();
      _titan.onResume();
      setState(() {
        _isPlaying = true;
        _userPaused = false;
      });
      _resetOsdTimer();
    }
  }

  /// ←/→: mueve el destino de la búsqueda sin tocar el video todavía.
  /// Mantenida ([repeat]) acelera.
  void _scrub({required bool forward, required bool repeat}) {
    if (_totalDuration <= Duration.zero) return;
    _scrubRepeats = repeat ? _scrubRepeats + 1 : 0;
    final target = MovieScrub.target(
      from: _scrubTarget ?? _currentPosition,
      forward: forward,
      repeats: _scrubRepeats,
      total: _totalDuration,
    );
    _osdTimer?.cancel();
    setState(() {
      _showOsd = true;
      _scrubTarget = target;
    });
    _scrubCommitTimer?.cancel();
    _scrubCommitTimer = Timer(_scrubCommitDelay, _commitScrub);
  }

  /// Salta al destino de la búsqueda (una sola vez).
  void _commitScrub() {
    _scrubCommitTimer?.cancel();
    final target = _scrubTarget;
    if (target == null || !mounted) return;
    setState(() => _scrubTarget = null);
    _seekTo(target);
    _resetOsdTimer();
  }

  void _cancelScrub() {
    _scrubCommitTimer?.cancel();
    if (_scrubTarget != null && mounted) {
      setState(() => _scrubTarget = null);
    }
  }

  /// Dónde estaba antes del último salto y cuándo fue: si el salto termina
  /// en error, reintentar vuelve ahí en vez de repetir el salto que falló.
  Duration _beforeLastSeek = Duration.zero;
  DateTime? _lastSeekAt;

  Future<void> _seekTo(Duration target) async {
    _beforeLastSeek = _currentPosition;
    _lastSeekAt = DateTime.now();
    _seekSettlesAt = DateTime.now().add(const Duration(seconds: 3));
    setState(() => _currentPosition = target);
    if (_titan.active) {
      // Primero salta Ranger y después el reproductor: mientras, cargando.
      setState(() => _isBuffering = true);
      await _titan.beforeSeek(target);
      if (!mounted) return;
    }
    await _engine.seekTo(target);
  }

  Future<void> _handleBack() async {
    if (_scrubTarget != null) {
      _cancelScrub();
      _resetOsdTimer();
      return;
    }
    // Con la interfaz visible, atrás la esconde (aunque esté cargando o en
    // pausa); el siguiente atrás sale.
    if (_showOsd && !_hasError) {
      _osdTimer?.cancel();
      setState(() => _showOsd = false);
      return;
    }

    // Guardar progreso final al salir
    if (_canSaveProgress) await _saveProgress();
    _progressSavedOnExit = true;

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// La película ya arrancó en su punto: antes, la posición todavía es 0 (o
  /// la del salto a medio hacer) y guardarla borraría el progreso real.
  bool get _canSaveProgress =>
      widget.saveProgress &&
      _playbackStarted &&
      _startAt == null &&
      _scrubTarget == null &&
      _totalDuration > Duration.zero;

  bool _playbackStarted = false;
  bool _progressSavedOnExit = false;
  bool _endHandled = false;

  /// Guarda por dónde va; las reglas (zonas, salir de Interesantes) son de
  /// [MovieLibrary].
  Future<void> _saveProgress({Duration? at}) => MovieLibrary.recordProgress(
    movie: widget.movie,
    position: at ?? _currentPosition,
    total: _totalDuration,
  );

  /// Terminó la película: queda vista y se vuelve al detalle.
  Future<void> _onPlaybackEnded() async {
    if (_endHandled) return;
    _endHandled = true;
    if (widget.saveProgress && _totalDuration > Duration.zero) {
      await _saveProgress(at: _totalDuration);
    }
    _progressSavedOnExit = true;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _osdTimer?.cancel();
    _positionTimer?.cancel();
    _scrubCommitTimer?.cancel();
    _focusNode.dispose();
    _position.dispose();
    _titan.close();

    // Guardar progreso al desmontar (si no se guardó ya al salir)
    if (!_progressSavedOnExit && _canSaveProgress) unawaited(_saveProgress());

    _engine.removeListener(_onEngineEvent);
    _engine.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final isArrow =
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;

    // Las flechas mantenidas aceleran la búsqueda; el resto sólo al apretar.
    if (isArrow && (event is KeyDownEvent || event is KeyRepeatEvent)) {
      if (_hasError) return KeyEventResult.handled;
      _scrub(
        forward: key == LogicalKeyboardKey.arrowRight,
        repeat: event is KeyRepeatEvent,
      );
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (TvKeyHandler.isActionKey(key)) {
      if (_hasError) {
        _retry();
      } else if (_scrubTarget != null) {
        _commitScrub();
      } else {
        _togglePlayPause();
      }
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
  }

  @override
  Widget build(BuildContext context) {
    final scrubTarget = _scrubTarget;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          onTap: () {
            _focusNode.requestFocus();
            _resetOsdTimer();
          },
          child: MoviePlayerDarkTheme(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Motor de video nativo en relación de aspecto cinematográfica completa
                // Franjas negras si la película no llena la pantalla (no el
                // gris de la superficie del tema).
                EnginePlayerView(
                  controller: _engine,
                  fit: BoxFit.contain,
                  background: Colors.black,
                ),

                // 2. Centro: error, destino de la búsqueda, cargando o pausa.
                Center(
                  child: _hasError
                      ? const MoviePlayerErrorPanel()
                      : scrubTarget != null
                      ? MoviePlayerScrubPreview(
                          target: scrubTarget,
                          from: _currentPosition,
                        )
                      : _isBuffering
                      ? const MoviePlayerStatusChip.loading()
                      : !_isPlaying
                      ? const MoviePlayerStatusChip.paused()
                      : const SizedBox.shrink(),
                ),

                // Subtítulo: abajo; con la interfaz visible, sobre el panel.
                if (_subtitleText.isNotEmpty && !_hasError)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    left: 120,
                    right: 120,
                    bottom: _showOsd ? 108 : 40,
                    child: Center(
                      child: MoviePlayerSubtitle(text: _subtitleText),
                    ),
                  ),

                // 3. Interfaz: franja superior y panel inferior de cristal
                // sobre viñetas suaves.
                AnimatedOpacity(
                  opacity: _showOsd && !_hasError ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 240),
                  child: IgnorePointer(
                    ignoring: !_showOsd || _hasError,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const _Vignette(top: true),
                        const _Vignette(top: false),
                        Positioned(
                          top: 24,
                          left: 32,
                          right: 32,
                          child: MoviePlayerTopBar(
                            title: widget.movie.displayName,
                            quality: qualityLabel(widget.stream.quality),
                            audio: _audioLabel,
                          ),
                        ),
                        Positioned(
                          bottom: 24,
                          left: 32,
                          right: 32,
                          // Se repinta sola con la posición, sin el resto.
                          child: RepaintBoundary(
                            child: ValueListenableBuilder<Duration>(
                              valueListenable: _position,
                              builder: (context, position, _) =>
                                  MoviePlayerBottomBar(
                                    position: position,
                                    duration: _totalDuration,
                                    isPlaying: _isPlaying,
                                    scrubTarget: scrubTarget,
                                  ),
                            ),
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
      ),
    );
  }
}

/// Oscurece el borde del video detrás de la franja o el panel, para que el
/// cristal se lea sobre imágenes claras.
class _Vignette extends StatelessWidget {
  const _Vignette({required this.top});

  final bool top;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: 0,
      right: 0,
      height: top ? 130 : 170,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
      ),
    );
  }
}
