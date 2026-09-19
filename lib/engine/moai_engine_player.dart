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

  const MoaiMediaSpec({
    required this.url,
    required this.title,
    this.headers = const {},
    this.userAgent,
    this.mimeType,
    this.drmLicenseUri,
    this.drmScheme,
  });
}

/// Controlador Dart del motor ExoPlayer nativo que renderiza a un
/// `SurfaceTexture` de Flutter (widget `Texture`). Sin PlatformView.
class MoaiEngineController extends ChangeNotifier {
  static const MethodChannel _control = MethodChannel('com.infomak.moai.tv/player');

  /// Tiempo máximo de buffering sin primer cuadro antes de reportar error
  /// accionable (evita el spinner infinito).
  static const Duration bufferingTimeout = Duration(seconds: 45);

  int? _handle;
  int? _textureId;
  StreamSubscription<dynamic>? _eventsSub;
  MoaiEngineEvent _event = const MoaiEngineEvent();
  Timer? _watchdog;

  int? get textureId => _textureId;
  MoaiEngineEvent get event => _event;
  bool get isPlaying => _event.isPlaying;
  bool get hasFirstFrame => _event.firstFrameRendered;
  bool get hasTexture => _textureId != null;
  bool get disposed => _handle == null;

  Future<void> create() async {
    if (_handle != null) return;
    try {
      final result = await _control.invokeMethod<Map<dynamic, dynamic>>('create');
      _handle = result!['handle'] as int;
      _textureId = result['textureId'] as int;
      debugPrint('[MoaiEngine] creado handle=$_handle texture=$_textureId');
      final events = EventChannel('com.infomak.moai.tv/player/events/$_handle');
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
        debugPrint('[MoaiEngine] ERROR code=${_event.errorCode} '
            'class=${_event.errorClass} msg=${_event.errorMessage}');
        break;
    }
    notifyListeners();
  }

  /// Vigila que el buffering no quede "congelado" sin primer cuadro.
  void _startWatchdog() {
    _stopWatchdog();
    _watchdog = Timer(bufferingTimeout, () {
      _watchdog = null;
      _event = _event.copyWith(
        state: MoaiEngineState.error,
        errorCode: -30,
        errorMessage: 'Sin primer cuadro tras ${bufferingTimeout.inSeconds}s '
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
    notifyListeners();
    debugPrint('[MoaiEngine] setMedia: "${spec.title}" '
        'mime=${spec.mimeType ?? '-'} drm=${spec.drmScheme ?? '-'} '
        'cabeceras=${spec.headers.length}');
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
    await _control.invokeMethod<void>(
        'seekTo', {'handle': _handle, 'positionMs': position.inMilliseconds});
  }

  Future<void> setVolume(double volume) async {
    await _control.invokeMethod<void>('setVolume', {'handle': _handle, 'volume': volume});
  }

  @override
  Future<void> dispose() async {
    _stopWatchdog();
    final handle = _handle;
    _handle = null;
    _textureId = null;
    debugPrint('[MoaiEngine] dispose handle=$handle');
    await _eventsSub?.cancel();
    _eventsSub = null;
    if (handle != null) {
      try {
        await _control.invokeMethod<void>('dispose', {'handle': handle});
      } catch (_) {
        // El motor ya puede estar cerrado (app en destrucción).
      }
    }
    super.dispose();
  }
}