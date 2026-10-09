import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Define los botones estándar de arcade (CPS-2 / FBNeo) como bitmasks.
class ArcadeButtons {
  static const int up = 1 << 0;
  static const int down = 1 << 1;
  static const int left = 1 << 2;
  static const int right = 1 << 3;

  static const int coin = 1 << 4;
  static const int start = 1 << 5;

  // Ataques (6 botones de Capcom CPS-2: 3 Puños + 3 Patadas)
  static const int punchLight = 1 << 6; // Low Punch (A)
  static const int punchMedium = 1 << 7; // Medium Punch (B)
  static const int punchHeavy = 1 << 8; // Heavy Punch (C / R1)

  static const int kickLight = 1 << 9; // Low Kick (X)
  static const int kickMedium = 1 << 10; // Medium Kick (Y)
  static const int kickHeavy = 1 << 11; // Heavy Kick (Z / R2)
}

/// Servicio singleton/provider para controlar el motor emulador nativo FBNeo vía MethodChannel.
class ArcadeEmulatorService extends ChangeNotifier {
  static const MethodChannel _channel =
      MethodChannel('com.infomak.moai/arcade_channel');

  bool _isInitialized = false;
  bool _isRunning = false;
  bool _isPaused = false;
  String? _currentRomPath;
  int _currentInputMask = 0;

  bool get isInitialized => _isInitialized;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  String? get currentRomPath => _currentRomPath;
  int get currentInputMask => _currentInputMask;

  ArcadeEmulatorService() {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onFrameRendered':
        notifyListeners();
        break;
      case 'onEmulatorError':
        final String error = call.arguments as String? ?? 'Error desconocido';
        if (kDebugMode) {
          print('[ArcadeEmulatorService] Error nativo: $error');
        }
        break;
    }
  }

  /// Inicializa la comunicación con el motor nativo de emulación.
  Future<bool> initializeEmulator() async {
    try {
      final bool result =
          await _channel.invokeMethod('initializeEmulator') ?? false;
      _isInitialized = result;
      notifyListeners();
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('[ArcadeEmulatorService] Error al inicializar: ${e.message}');
      }
      return false;
    }
  }

  /// Configura la ruta dinámica del archivo .so del core de emulación.
  Future<bool> setCustomCorePath(String path) async {
    try {
      final bool result = await _channel.invokeMethod('setCustomCorePath', {'path': path}) ?? false;
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('[ArcadeEmulatorService] Error al configurar ruta de core: ${e.message}');
      }
      return false;
    }
  }

  /// Carga y ejecuta una ROM dada su ruta local (ej. /sdcard/roms/mvsc.zip).
  Future<bool> loadRom(String path) async {
    try {
      final bool result =
          await _channel.invokeMethod('loadRom', {'path': path}) ?? false;
      if (result) {
        _currentRomPath = path;
        _isRunning = true;
        _isPaused = false;
      }
      notifyListeners();
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('[ArcadeEmulatorService] Error al cargar ROM $path: ${e.message}');
      }
      return false;
    }
  }

  /// Actualiza la máscara de entrada (botones presionados actualmente).
  Future<void> sendInputMask(int mask) async {
    if (_currentInputMask == mask) return;
    _currentInputMask = mask;
    try {
      await _channel.invokeMethod('sendInputState', {'mask': mask});
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('[ArcadeEmulatorService] Error al enviar input: ${e.message}');
      }
    }
  }

  /// Pausa la emulación.
  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
      _isPaused = true;
      notifyListeners();
    } on PlatformException catch (_) {}
  }

  /// Reanuda la emulación.
  Future<void> resume() async {
    try {
      await _channel.invokeMethod('resume');
      _isPaused = false;
      notifyListeners();
    } on PlatformException catch (_) {}
  }

  /// Reinicia el juego actual.
  Future<void> reset() async {
    try {
      await _channel.invokeMethod('reset');
      notifyListeners();
    } on PlatformException catch (_) {}
  }

  /// Detiene y libera recursos del emulador.
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
      _isRunning = false;
      _isPaused = false;
      _currentRomPath = null;
      notifyListeners();
    } on PlatformException catch (_) {}
  }
}
