import 'package:moai3/platform/platform_channels.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Estados que el motor nativo reporta.
enum MoaiEngineState { idle, buffering, ready, ended, error }

/// Instantánea del último evento emitido por el motor.
class MoaiEngineEvent {
  final MoaiEngineState state;
  final bool isPlaying;
  final bool firstFrameRendered;
  final int? videoWidth;
  final int? videoHeight;
  final int? errorCode;
  final String? errorMessage;
  final String? errorClass;

  const MoaiEngineEvent({
    this.state = MoaiEngineState.idle,
    this.isPlaying = false,
    this.firstFrameRendered = false,
    this.videoWidth,
    this.videoHeight,
    this.errorCode,
    this.errorMessage,
    this.errorClass,
  });

  MoaiEngineEvent copyWith({
    MoaiEngineState? state,
    bool? isPlaying,
    bool? firstFrameRendered,
    int? videoWidth,
    int? videoHeight,
    int? errorCode,
    String? errorMessage,
    String? errorClass,
    bool clearError = false,
  }) {
    return MoaiEngineEvent(
      state: state ?? this.state,
      isPlaying: isPlaying ?? this.isPlaying,
      firstFrameRendered: firstFrameRendered ?? this.firstFrameRendered,
      videoWidth: videoWidth ?? this.videoWidth,
      videoHeight: videoHeight ?? this.videoHeight,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorClass: clearError ? null : (errorClass ?? this.errorClass),
    );
  }

  bool get hasError => errorCode != null;
}

/// Contrato de lo que se le pide reproducir al motor.
class MoaiMediaSpec {
  final String url;
  final Map<String, String> headers;
  final String? userAgent;
  final String? mimeType;
  final String? drmLicenseUri;
  final String? drmScheme;
  final String title;

  /// Idioma de audio preferido ("spa", "eng"…): con varios audios en el
  /// stream, ExoPlayer elige éste si lo hay.
  final String? preferredAudioLanguage;

  /// Subtítulo externo (SRT/VTT) a mostrar; sin URL, sin subtítulos.
  final String? subtitleUrl;
  final String? subtitleMimeType;
  final String? subtitleLanguage;

  const MoaiMediaSpec({
    required this.url,
    required this.title,
    this.headers = const {},
    this.userAgent,
    this.mimeType,
    this.drmLicenseUri,
    this.drmScheme,
    this.preferredAudioLanguage,
    this.subtitleUrl,
    this.subtitleMimeType,
    this.subtitleLanguage,
  });
}

/// Un audio del stream, como lo informa ExoPlayer.
class MoaiAudioTrack {
  const MoaiAudioTrack({this.language, this.label, this.selected = false});

  /// Código de idioma normalizado por ExoPlayer ("es", "en", "es-419"…).
  final String? language;

  /// Nombre de la pista si el stream lo trae (p. ej. "Latino").
  final String? label;

  /// Es la que está sonando.
  final bool selected;
}

/// Por dónde va la reproducción, según [MoaiEngineController.getStatus].
class MoaiPlaybackStatus {
  const MoaiPlaybackStatus({
    required this.position,
    required this.duration,
    required this.buffered,
  });

  static const zero = MoaiPlaybackStatus(
    position: Duration.zero,
    duration: Duration.zero,
    buffered: Duration.zero,
  );

  final Duration position;
  final Duration duration;

  /// Hasta dónde hay video cargado.
  final Duration buffered;
}

/// Controlador Dart del motor ExoPlayer nativo que renderiza a un
/// `SurfaceTexture` de Flutter (widget `Texture`). Sin PlatformView.
class MoaiEngineController extends ChangeNotifier {
  static const MethodChannel _control = PlatformChannels.player;

  /// Tiempo máximo de buffering sin primer cuadro antes de reportar error
  /// accionable (evita el spinner infinito).
  static const Duration bufferingTimeout = Duration(seconds: 45);

  /// Lo mismo, pero con el video ya andando (un corte a mitad). Por defecto
  /// igual que al arrancar; las películas esperan más (Ranger puede tardar
  /// en bajar el tramo de un salto).
  final Duration rebufferTimeout;

  MoaiEngineController({this.rebufferTimeout = bufferingTimeout});

  int? _handle;
  int? _textureId;
  StreamSubscription<dynamic>? _eventsSub;
  MoaiEngineEvent _event = const MoaiEngineEvent();
  Timer? _watchdog;

  List<MoaiAudioTrack> _audioTracks = const [];

  int? get textureId => _textureId;
  MoaiEngineEvent get event => _event;

  /// Audios del stream actual (vacío hasta que ExoPlayer los conoce).
  List<MoaiAudioTrack> get audioTracks => _audioTracks;

  String _subtitleText = '';

  /// Subtítulo que corresponde mostrar ahora ('' si ninguno). Lo dibuja
  /// Flutter: el video va en una textura, sin la vista de ExoPlayer.
  String get subtitleText => _subtitleText;
  bool get isPlaying => _event.isPlaying;
  bool get hasTexture => _textureId != null;

  Future<void> create() async {
    if (_handle != null) return;
    try {
      final result = await _control.invokeMethod<Map<dynamic, dynamic>>(
        'create',
      );
      _handle = result!['handle'] as int;
      _textureId = result['textureId'] as int;
      debugPrint('[MoaiEngine] creado handle=$_handle texture=$_textureId');
      final events = PlatformChannels.playerEvents(_handle!);
      _eventsSub = events.receiveBroadcastStream().listen(_onNativeEvent);
    } catch (e) {
      _event = _event.copyWith(
        state: MoaiEngineState.error,
        errorCode: -1,
        errorMessage: 'No se pudo crear el reproductor nativo: $e',
        errorClass: 'EngineCreateFailure',
      );
      notifyListeners();
      debugPrint('[MoaiEngine] fallo al crear: $e');
    }
  }

  void _onNativeEvent(dynamic raw) {
    if (raw is! Map) return;
    final event = raw['event'] as String?;
    switch (event) {
      case 'state':
        final value = raw['value'] as String?;
        _event = _event.copyWith(state: _mapState(value));
        if (_event.state == MoaiEngineState.buffering) {
          _startWatchdog();
        } else {
          _stopWatchdog();
        }
        debugPrint('[MoaiEngine] estado -> ${_event.state.name}');
        break;
      case 'playing':
        _event = _event.copyWith(isPlaying: raw['value'] == true);
        debugPrint('[MoaiEngine] playing=${raw['value']}');
        break;
      case 'cues':
        _subtitleText = (raw['value'] as String?) ?? '';
        break;
      case 'audioTracks':
        final list = raw['value'] as List? ?? const [];
        _audioTracks = [
          for (final t in list)
            if (t is Map)
              MoaiAudioTrack(
                language: t['language'] as String?,
                label: t['label'] as String?,
                selected: t['selected'] == true,
              ),
        ];
        break;
      case 'firstFrame':
        _event = _event.copyWith(firstFrameRendered: true);
        _stopWatchdog();
        debugPrint('[MoaiEngine] PRIMER CUADRO renderizado');
        break;
      case 'videoSize':
        final sizeMap = raw['value'] as Map?;
        _event = _event.copyWith(
          videoWidth: (sizeMap?['width'] ?? raw['width']) as int?,
          videoHeight: (sizeMap?['height'] ?? raw['height']) as int?,
        );
        break;
      case 'error':
        final errMap = raw['value'] as Map?;
        _event = _event.copyWith(
          state: MoaiEngineState.error,
          errorCode: (errMap?['code'] ?? raw['code']) as int?,
          errorMessage: (errMap?['message'] ?? raw['message']) as String?,
          errorClass: (errMap?['class'] ?? raw['class']) as String?,
        );
        _stopWatchdog();
        debugPrint(
          '[MoaiEngine] ERROR code=${_event.errorCode} '
          'class=${_event.errorClass} msg=${_event.errorMessage}',
        );
        break;
    }
    notifyListeners();
  }

  /// Vigila que el buffering no quede "congelado" sin primer cuadro.
  void _startWatchdog() {
    _stopWatchdog();
    final timeout = _event.firstFrameRendered
        ? rebufferTimeout
        : bufferingTimeout;
    _watchdog = Timer(timeout, () {
      _watchdog = null;
      _event = _event.copyWith(
        state: MoaiEngineState.error,
        errorCode: -30,
        errorMessage:
            'Sin video tras ${timeout.inSeconds}s '
            'de buffering (¿red? ¿licencia DRM?).',
        errorClass: 'BufferingTimeout',
      );
      _stopWatchdog();
      notifyListeners();
      debugPrint('[MoaiEngine] WATCHDOG: buffering sin primer cuadro');
    });
  }

  void _stopWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  MoaiEngineState _mapState(String? value) {
    switch (value) {
      case 'ready':
        return MoaiEngineState.ready;
      case 'buffering':
        return MoaiEngineState.buffering;
      case 'ended':
        return MoaiEngineState.ended;
      default:
        return MoaiEngineState.idle;
    }
  }

  /// Carga un flujo resuelto en el motor y comienza a reproducir.
  Future<void> setMedia(MoaiMediaSpec spec) async {
    await create();
    if (_handle == null) return;
    _stopWatchdog();
    _event = const MoaiEngineEvent(state: MoaiEngineState.buffering);
    _audioTracks = const [];
    _subtitleText = '';
    notifyListeners();
    debugPrint(
      '[MoaiEngine] setMedia: "${spec.title}" '
      'mime=${spec.mimeType ?? '-'} drm=${spec.drmScheme ?? '-'} '
      'cabeceras=${spec.headers.length}',
    );
    await _control.invokeMethod<void>('setMedia', {
      'handle': _handle,
      'url': spec.url,
      'headers': spec.headers,
      'userAgent': spec.userAgent,
      'mimeType': spec.mimeType,
      'drmLicenseUri': spec.drmLicenseUri,
      'drmScheme': spec.drmScheme,
      'title': spec.title,
      'artist': 'Moai',
      'preferredAudioLanguage': spec.preferredAudioLanguage,
      'subtitleUrl': spec.subtitleUrl,
      'subtitleMimeType': spec.subtitleMimeType,
      'subtitleLanguage': spec.subtitleLanguage,
    });
    await play();
  }

  Future<void> play() async {
    await _control.invokeMethod<void>('play', {'handle': _handle});
  }

  Future<void> pause() async {
    await _control.invokeMethod<void>('pause', {'handle': _handle});
  }

  Future<void> seekTo(Duration position) async {
    await _control.invokeMethod<void>('seekTo', {
      'handle': _handle,
      'positionMs': position.inMilliseconds,
    });
  }

  Future<Duration> getPosition() async {
    if (_handle == null) return Duration.zero;
    try {
      final pos = await _control.invokeMethod<num>('getPosition', {
        'handle': _handle,
      });
      return Duration(milliseconds: pos?.toInt() ?? 0);
    } catch (_) {
      return Duration.zero;
    }
  }

  Future<Duration> getDuration() async {
    if (_handle == null) return Duration.zero;
    try {
      final dur = await _control.invokeMethod<num>('getDuration', {
        'handle': _handle,
      });
      final ms = dur?.toInt() ?? 0;
      return ms > 0 ? Duration(milliseconds: ms) : Duration.zero;
    } catch (_) {
      return Duration.zero;
    }
  }

  /// Hasta dónde hay video cargado (para contarle a Ranger cuánto falta).
  Future<Duration> getBufferedPosition() async {
    if (_handle == null) return Duration.zero;
    try {
      final pos = await _control.invokeMethod<num>('getBufferedPosition', {
        'handle': _handle,
      });
      return Duration(milliseconds: pos?.toInt() ?? 0);
    } catch (_) {
      return Duration.zero;
    }
  }

  /// Posición, duración y hasta dónde hay cargado, en una sola llamada al
  /// motor. Sin motor o si falla, todo en cero. Una duración desconocida
  /// (ExoPlayer la da negativa) queda en cero.
  Future<MoaiPlaybackStatus> getStatus() async {
    if (_handle == null) return MoaiPlaybackStatus.zero;
    try {
      final map = await _control.invokeMapMethod<String, dynamic>('getStatus', {
        'handle': _handle,
      });
      Duration ms(String key) {
        final value = (map?[key] as num?)?.toInt() ?? 0;
        return value > 0 ? Duration(milliseconds: value) : Duration.zero;
      }

      return MoaiPlaybackStatus(
        position: ms('position'),
        duration: ms('duration'),
        buffered: ms('buffered'),
      );
    } catch (_) {
      return MoaiPlaybackStatus.zero;
    }
  }

  Future<void> setVolume(double volume) async {
    await _control.invokeMethod<void>('setVolume', {
      'handle': _handle,
      'volume': volume,
    });
  }

  /// Libera el reproductor esperando que el canal nativo cierre ExoPlayer y libere sockets/texturas.
  Future<void> releaseAsync() async {
    _stopWatchdog();
    final handle = _handle;
    _handle = null;
    _textureId = null;
    debugPrint('[MoaiEngine] releaseAsync handle=$handle');
    await _eventsSub?.cancel();
    _eventsSub = null;
    if (handle != null) {
      try {
        await _control.invokeMethod<void>('dispose', {'handle': handle});
      } catch (e) {
        debugPrint('[MoaiEngine] error en dispose nativo: $e');
      }
    }
  }

  @override
  void dispose() {
    unawaited(releaseAsync());
    super.dispose();
  }
}
