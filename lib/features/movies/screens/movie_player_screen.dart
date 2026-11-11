import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/engine/engine_player_view.dart';
import 'package:moai3/engine/moai_engine_player.dart';
import 'package:moai3/features/movies/movie_player_format.dart';
import 'package:moai3/features/movies/titan_playback_bridge.dart';
import 'package:moai3/features/movies/widgets/movie_player_osd.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/services/movie_audio_choices.dart';
import 'package:moai3/services/movie_library.dart';
import 'package:moai3/state/movie_recommendations_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:provider/provider.dart';

/// Pantalla completa de reproducción de películas para Smart TV.
///
/// Controles: OK pausa/reanuda; ←/→ buscan (mantenidas aceleran) y el salto
/// se hace una sola vez al confirmar con OK o al soltar; atrás cancela la
/// búsqueda, esconde la interfaz o sale. ↓ pasa a las píldoras de audio y
/// subtítulos (←/→ las recorren, OK abre su menú, ↑ o atrás vuelven). Si el
/// video falla, OK reintenta desde el mismo punto.
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

  /// Cuál de los audios de ese idioma se le pide al motor.
  int _preferredAudioOccurrence = 0;

  /// El audio elegido a mano en esta película (o guardado de otra vez).
  MovieAudioOption? _chosenAudio;
  bool _savedAudioChecked = false;

  /// Audios del stream según el motor (vacío hasta que los conoce).
  List<MoaiAudioTrack> _audioTracks = const [];

  /// Subtítulo elegido según Ajustes (null: apagados o no hay ese idioma).
  VodSubtitleOption? _subtitle;

  /// Texto del subtítulo de este momento, según el motor.
  String _subtitleText = '';

  /// Audios y subtítulos que se pueden elegir en esta película.
  late final List<MovieAudioOption> _audioOptions = movieAudioOptions(
    widget.stream.audioInfo,
  );
  late final List<VodSubtitleOption> _subtitleOptions = subtitleOptions(
    widget.stream.subtitles,
  );

  /// Cartel de recomendar (SPEC-51): la respuesta elegida, o null si no está.
  MovieRecommendAnswer? _recommendAnswer;
  Timer? _recommendTimer;

  /// Ya se decidió en esta reproducción: se preguntó o se llegó saltando.
  bool _recommendSettled = false;
  static const _recommendWindow = Duration(minutes: 5);
  static const _recommendVisibleFor = Duration(seconds: 20);

  /// Píldora elegida (null: ←/→ buscan en la película).
  MoviePlayerMenu? _selectedMenu;

  /// Menú abierto y su opción elegida.
  MoviePlayerMenu? _openMenu;
  int _menuIndex = 0;

  /// Lo que se puede cambiar: el audio con más de uno y, con subtítulos,
  /// cuál y su tamaño.
  List<MoviePlayerMenu> get _menus => [
    if (_audioOptions.length > 1) MoviePlayerMenu.audio,
    if (_subtitleOptions.isNotEmpty) ...[
      MoviePlayerMenu.subtitles,
      MoviePlayerMenu.size,
    ],
  ];

  /// El audio que suena: el del motor o, mientras no se sabe, el pedido.
  /// El motor sólo sabe el idioma: entre dos iguales, vale el elegido.
  MovieAudioOption? get _currentAudio {
    String? code;
    for (final track in _audioTracks) {
      if (!track.selected) continue;
      code = audioLanguageCode(track.language ?? '');
      if (code != null) break;
    }
    code ??= _preferredAudio;
    if (_chosenAudio?.code == code) return _chosenAudio;
    for (final option in _audioOptions) {
      if (option.code == code) return option;
    }
    return _audioOptions.firstOrNull;
  }

  MovieSubtitleSize get _subtitleSize =>
      context.read<TvSettingsProvider?>()?.movieSubtitleSize ??
      MovieSubtitleSize.defaultValue;

  List<MoviePlayerMenuOption> get _menuOptions => switch (_openMenu) {
    MoviePlayerMenu.audio => [
      for (final option in _audioOptions)
        MoviePlayerMenuOption(
          movieAudioLabel(option),
          current: option == _currentAudio,
        ),
    ],
    MoviePlayerMenu.subtitles => [
      MoviePlayerMenuOption(
        LocaleKeys.settings_movies_subtitles_off.tr(),
        current: _subtitle == null,
      ),
      for (final option in _subtitleOptions)
        MoviePlayerMenuOption(
          subtitleLabel(option),
          current:
              _subtitle != null &&
              subtitleLabel(_subtitle!) == subtitleLabel(option),
        ),
    ],
    MoviePlayerMenu.size => [
      for (final size in MovieSubtitleSize.values)
        MoviePlayerMenuOption(
          subtitleSizeLabel(size),
          current: size == _subtitleSize,
        ),
    ],
    null => const [],
  };

  /// Chip de audio: el que suena según el motor; mientras no se sabe, el
  /// pedido (si la película lo trae) o el primero de la API.
  String get _audioLabel {
    final current = _currentAudio;
    if (current != null && current.sameLanguage > 1) {
      return movieAudioLabel(current);
    }
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
        if (failed) _selectedMenu = _openMenu = null;
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

  /// Lo elegido otra vez en esta película manda sobre el ajuste general.
  Future<void> _restoreSavedAudio() async {
    if (_savedAudioChecked || !widget.saveProgress) return;
    _savedAudioChecked = true;
    final saved = await MovieAudioChoices.read(widget.movie.contentId);
    if (saved == null) return;
    for (final option in _audioOptions) {
      if (option.code == saved.code && option.occurrence == saved.occurrence) {
        _chosenAudio = option;
        _preferredAudio = option.code;
        _preferredAudioOccurrence = option.occurrence;
      }
    }
  }

  Future<void> _initPlayer() async {
    try {
      await _restoreSavedAudio();
      if (!mounted) return;
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
          preferredAudioOccurrence: _preferredAudioOccurrence,
          startPosition: _loadPosition,
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
    _reloadAt(seekFailed ? _beforeLastSeek : _currentPosition);
  }

  void _maybeAskRecommendation() {
    if (_recommendSettled || !widget.saveProgress) return;
    final remaining = _totalDuration - _currentPosition;
    if (_totalDuration <= _recommendWindow ||
        remaining > _recommendWindow ||
        remaining <= Duration.zero) {
      return;
    }
    // Sin pisar lo que se esté usando: se reintenta en la próxima vuelta.
    if (_isBuffering ||
        !_isPlaying ||
        _hasError ||
        _openMenu != null ||
        _selectedMenu != null ||
        _scrubTarget != null) {
      return;
    }
    _recommendSettled = true;
    final recommendations = context.read<MovieRecommendationsProvider?>();
    if (recommendations == null ||
        !recommendations.canRecommend ||
        !recommendations.shouldAsk(widget.movie.contentId)) {
      return;
    }
    // Arranca en Cancelar: un OK distraído no recomienda.
    setState(() => _recommendAnswer = MovieRecommendAnswer.cancel);
    _recommendTimer = Timer(_recommendVisibleFor, _closeRecommendPrompt);
  }

  void _closeRecommendPrompt() {
    _recommendTimer?.cancel();
    if (mounted) setState(() => _recommendAnswer = null);
  }

  KeyEventResult _onRecommendKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    final answer = _recommendAnswer!;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final step = key == LogicalKeyboardKey.arrowLeft ? -1 : 1;
      const answers = MovieRecommendAnswer.values;
      setState(() {
        _recommendAnswer =
            answers[(answer.index + step).clamp(0, answers.length - 1)];
      });
    } else if (TvKeyHandler.isActionKey(key)) {
      _applyRecommendAnswer(answer);
    } else if (_isBackKey(key)) {
      _closeRecommendPrompt();
    }
    return KeyEventResult.handled;
  }

  void _applyRecommendAnswer(MovieRecommendAnswer answer) {
    _closeRecommendPrompt();
    final recommendations = context.read<MovieRecommendationsProvider?>();
    if (recommendations == null) return;
    switch (answer) {
      case MovieRecommendAnswer.yes:
        unawaited(recommendations.setVote(widget.movie, MovieVote.up));
        MoaiSnackBar.show(
          context,
          message: LocaleKeys.movies_recommend_sent.tr(),
          icon: MoaiIcons.vodRecommend,
        );
      case MovieRecommendAnswer.no:
        unawaited(recommendations.setVote(widget.movie, MovieVote.down));
      case MovieRecommendAnswer.cancel:
        break;
    }
  }

  /// Desde dónde arranca la próxima carga del video.
  Duration _loadPosition = Duration.zero;

  /// Vuelve a cargar el video y lo retoma en [resumeAt]: primero salta
  /// Ranger y el video arranca directo ahí, porque el proxy da 404 por los
  /// tramos anteriores.
  void _reloadAt(Duration resumeAt) {
    _lastSeekAt = null;
    _startAt = null;
    _loadPosition = resumeAt;
    _seekSettlesAt = DateTime.now().add(const Duration(seconds: 3));
    _currentPosition = resumeAt;
    _titan.reset();
    setState(() {
      _hasError = false;
      _isBuffering = true;
      _userPaused = false;
    });
    _resetOsdTimer();
    unawaited(
      _titan.beforeSeek(resumeAt).then((_) {
        if (mounted) _initPlayer();
      }),
    );
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
          // Mientras se recarga el motor dice 0: la barra se queda donde está.
          if (!settling && _startAt == null) _currentPosition = pos;
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
          _maybeAskRecommendation();
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
    // Con las píldoras o un menú hay que leer y elegir: un poco más de tiempo.
    _scheduleOsdHide(Duration(seconds: _selectedMenu == null ? 4 : 8));
  }

  void _scheduleOsdHide(Duration after) {
    _osdTimer?.cancel();
    _osdTimer = Timer(after, () {
      if (!mounted || !_showOsd) return;
      if (_userPaused || _scrubTarget != null || _hasError) return;
      if (_isPlaying && !_isBuffering) {
        setState(() {
          _showOsd = false;
          _selectedMenu = _openMenu = null;
        });
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
    if (_totalDuration > Duration.zero &&
        target >= _totalDuration - _recommendWindow) {
      _recommendSettled = true;
    }
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
    _recommendTimer?.cancel();
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

  static bool _isBackKey(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.backspace ||
      key == LogicalKeyboardKey.goBack;

  /// Con un menú abierto: ↑/↓ recorren, OK elige, ← o atrás lo cierran.
  KeyEventResult _onMenuKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final last = _menuOptions.length - 1;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final step = key == LogicalKeyboardKey.arrowUp ? -1 : 1;
      setState(() => _menuIndex = (_menuIndex + step).clamp(0, last));
      _resetOsdTimer();
    } else if (event is KeyDownEvent) {
      if (TvKeyHandler.isActionKey(key)) {
        _applyMenuOption(_menuIndex);
      } else if (key == LogicalKeyboardKey.arrowLeft || _isBackKey(key)) {
        setState(() => _openMenu = null);
        _resetOsdTimer();
      }
    }
    return KeyEventResult.handled;
  }

  /// En las píldoras: ←/→ recorren, OK abre, ↑ o atrás vuelven a la barra.
  KeyEventResult _onMenuBarKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    final menus = _menus;
    final at = menus.indexOf(_selectedMenu!);
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final step = key == LogicalKeyboardKey.arrowLeft ? -1 : 1;
      setState(() {
        _selectedMenu = menus[(at + step).clamp(0, menus.length - 1)];
      });
    } else if (TvKeyHandler.isActionKey(key)) {
      _openSelectedMenu();
    } else if (key == LogicalKeyboardKey.arrowUp || _isBackKey(key)) {
      setState(() => _selectedMenu = null);
    }
    _resetOsdTimer();
    return KeyEventResult.handled;
  }

  /// Abre el menú de la píldora con el foco en lo que está en uso.
  void _openSelectedMenu() {
    setState(() {
      _openMenu = _selectedMenu;
      final current = _menuOptions.indexWhere((o) => o.current);
      _menuIndex = current < 0 ? 0 : current;
    });
  }

  /// Aplica la opción [index] del menú abierto. Audio y subtítulo valen para
  /// esta película (el ajuste general no cambia; el audio queda recordado) y
  /// se fijan al cargar el video: se recarga en el mismo punto. El tamaño se
  /// ve al instante y queda abierto para probar.
  void _applyMenuOption(int index) {
    final resumeAt = _startAt ?? _currentPosition;
    switch (_openMenu) {
      case MoviePlayerMenu.audio:
        final option = _audioOptions[index];
        final changed = option != _currentAudio;
        setState(() => _selectedMenu = _openMenu = null);
        if (changed) {
          _chosenAudio = option;
          _preferredAudio = option.code;
          _preferredAudioOccurrence = option.occurrence;
          if (widget.saveProgress) {
            unawaited(
              MovieAudioChoices.save(
                widget.movie.contentId,
                code: option.code,
                occurrence: option.occurrence,
              ),
            );
          }
          _reloadAt(resumeAt);
        } else {
          _resetOsdTimer();
        }
      case MoviePlayerMenu.subtitles:
        final next = index == 0 ? null : _subtitleOptions[index - 1];
        final changed = next?.url != _subtitle?.url;
        setState(() => _selectedMenu = _openMenu = null);
        if (changed) {
          _subtitle = next;
          _reloadAt(resumeAt);
        } else {
          _resetOsdTimer();
        }
      case MoviePlayerMenu.size:
        context.read<TvSettingsProvider?>()?.setMovieSubtitleSize(
          MovieSubtitleSize.values[index],
        );
        _resetOsdTimer();
      case null:
        break;
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_recommendAnswer != null) return _onRecommendKey(event);
    if (_openMenu != null) return _onMenuKey(event);
    if (_selectedMenu != null) return _onMenuBarKey(event);
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
    if (key == LogicalKeyboardKey.arrowDown &&
        !_hasError &&
        _scrubTarget == null &&
        _menus.isNotEmpty) {
      setState(() => _selectedMenu = _menus.first);
      _resetOsdTimer();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.contextMenu) {
      _resetOsdTimer();
      return KeyEventResult.handled;
    }
    if (_isBackKey(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scrubTarget = _scrubTarget;
    final menus = _menus;
    final selectedMenu = _selectedMenu;
    final subtitleFontSize = context
        .select<TvSettingsProvider?, MovieSubtitleSize>(
          (s) => s?.movieSubtitleSize ?? MovieSubtitleSize.defaultValue,
        )
        .fontSize;
    // Eligiendo el tamaño, una muestra si en ese momento nadie habla.
    final subtitleText =
        _subtitleText.isEmpty && _openMenu == MoviePlayerMenu.size
        ? LocaleKeys.movies_player_subtitle_sample.tr()
        : _subtitleText;

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

                if (_recommendAnswer != null)
                  Positioned(
                    top: 72,
                    right: 40,
                    child: MovieRecommendPrompt(selected: _recommendAnswer!),
                  ),

                // Subtítulo: abajo; con la interfaz visible, sobre los controles.
                if (subtitleText.isNotEmpty && !_hasError)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    left: 120,
                    right: 120,
                    bottom: _showOsd ? 114 : 40,
                    child: Center(
                      child: MoviePlayerSubtitle(
                        text: subtitleText,
                        fontSize: subtitleFontSize,
                      ),
                    ),
                  ),

                // 3. Interfaz: sin paneles, directo sobre un oscurecido suave
                // arriba y abajo.
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
                          left: 40,
                          right: 40,
                          child: MoviePlayerTopBar(
                            title: widget.movie.displayName,
                            quality: qualityLabel(widget.stream.quality),
                            audio: _audioLabel,
                          ),
                        ),
                        Positioned(
                          bottom: 24,
                          left: 40,
                          right: 40,
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
                                    menus: menus,
                                    selectedMenu: selectedMenu,
                                  ),
                            ),
                          ),
                        ),
                        if (_openMenu != null)
                          Positioned(
                            right: 40,
                            bottom: 24 + MoviePlayerBottomBar.menuRowHeight + 8,
                            child: MoviePlayerMenuPanel(
                              options: _menuOptions,
                              focused: _menuIndex,
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

/// Oscurece suavemente arriba y abajo para que los controles se lean sin
/// paneles: varios tonos para que no se note dónde termina.
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
      height: top ? 120 : 200,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: top
                ? const [
                    Color(0x8C000000),
                    Color(0x40000000),
                    Color(0x00000000),
                  ]
                : const [
                    Color(0xCC000000),
                    Color(0x8C000000),
                    Color(0x33000000),
                    Color(0x00000000),
                  ],
          ),
        ),
      ),
    );
  }
}
