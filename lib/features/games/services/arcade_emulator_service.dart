import 'package:moai3/platform/platform_channels.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';

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

/// Modelo que representa la asignación de un mando o control remoto a un jugador.
class GamepadAssignment {
  final int player;
  final String? deviceName;
  final bool isRemote;

  const GamepadAssignment({
    required this.player,
    this.deviceName,
    this.isRemote = false,
  });
}

/// Servicio singleton/provider para controlar el motor emulador nativo FBNeo vía MethodChannel.
class ArcadeEmulatorService {
  static const MethodChannel _channel =
      PlatformChannels.arcade;

  /// Retardo de input del lockstep de netplay (SPEC-38).
  static const int netplayInputDelayFrames = 3;

  final StreamController<GamepadAssignment> _onGamepadAssignedController =
      StreamController<GamepadAssignment>.broadcast();
  final StreamController<void> _onRequestExitController =
      StreamController<void>.broadcast();

  Stream<GamepadAssignment> get onGamepadAssigned => _onGamepadAssignedController.stream;
  Stream<void> get onRequestExit => _onRequestExitController.stream;

  int _currentInputMask = 0;

  ArcadeEmulatorService() {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onGamepadAssigned':
        int player = 0;
        String? deviceName;
        bool isRemote = false;
        if (call.arguments is Map) {
          final map = call.arguments as Map;
          player = map['player'] as int? ?? 0;
          deviceName = map['name'] as String?;
          isRemote = map['isRemote'] as bool? ?? false;
        } else if (call.arguments is int) {
          player = call.arguments as int;
        }
        if (!_onGamepadAssignedController.isClosed) {
          _onGamepadAssignedController.add(
            GamepadAssignment(
              player: player,
              deviceName: deviceName,
              isRemote: isRemote,
            ),
          );
        }
        break;
      case 'onRequestExitGame':
        if (!_onRequestExitController.isClosed) {
          _onRequestExitController.add(null);
        }
        break;
      case 'onEmulatorError':
        final String error = call.arguments as String? ??
            LocaleKeys.common_error_unknown.tr();
        if (kDebugMode) {
          debugPrint('[ArcadeEmulatorService] Error nativo: $error');
        }
        break;
    }
  }

  /// Inicializa la comunicación con el motor nativo de emulación.
  Future<bool> initializeEmulator() async {
    try {
      final bool result =
          await _channel.invokeMethod('initializeEmulator') ?? false;
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[ArcadeEmulatorService] Error al inicializar: ${e.message}');
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
        debugPrint('[ArcadeEmulatorService] Error al configurar ruta de core: ${e.message}');
      }
      return false;
    }
  }

  /// Carga y ejecuta una ROM dada su ruta local (ej. /sdcard/roms/mvsc.zip).
  Future<bool> loadRom(String path) async {
    try {
      final bool result =
          await _channel.invokeMethod('loadRom', {'path': path}) ?? false;
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[ArcadeEmulatorService] Error al cargar ROM $path: ${e.message}');
      }
      return false;
    }
  }

  /// Actualiza la máscara de entrada (botones presionados actualmente) para un jugador específico (0=P1, 1=P2).
  Future<void> sendInputMask(int mask, {int player = 0}) async {
    if (player == 0) {
      if (_currentInputMask == mask) return;
      _currentInputMask = mask;
    }
    try {
      await _channel.invokeMethod('sendInputState', {'mask': mask, 'player': player});
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[ArcadeEmulatorService] Error al enviar input: ${e.message}');
      }
    }
  }

  Future<void> netplayEnable({
    required bool enabled,
    int delayFrames = netplayInputDelayFrames,
    bool isHost = true,
  }) async {
    try {
      await _channel.invokeMethod('netplayEnable', {
        'enabled': enabled,
        'delayFrames': delayFrames,
        'isHost': isHost,
      });
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[ArcadeEmulatorService] netplayEnable: ${e.message}');
      }
    }
  }

  Future<void> netplaySubmitLocalInput({required int frame, required int mask}) async {
    try {
      await _channel.invokeMethod('netplaySubmitLocalInput', {
        'frame': frame,
        'mask': mask,
      });
    } on PlatformException catch (_) {}
  }

  Future<void> netplaySubmitRemoteInput({required int frame, required int mask}) async {
    try {
      await _channel.invokeMethod('netplaySubmitRemoteInput', {
        'frame': frame,
        'mask': mask,
      });
    } on PlatformException catch (_) {}
  }

  Future<int> netplayGetFrame() async {
    try {
      final v = await _channel.invokeMethod<dynamic>('netplayGetFrame');
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    } on PlatformException catch (_) {
      return 0;
    }
  }

  /// Pausa la emulación.
  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } on PlatformException catch (_) {}
  }

  /// Reanuda la emulación.
  Future<void> resume() async {
    try {
      await _channel.invokeMethod('resume');
    } on PlatformException catch (_) {}
  }

  /// Reinicia el juego actual.
  Future<void> reset() async {
    try {
      await _channel.invokeMethod('reset');
    } on PlatformException catch (_) {}
  }

  /// Detiene y libera recursos del emulador.
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } on PlatformException catch (_) {}
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _onGamepadAssignedController.close();
    _onRequestExitController.close();
  }
}
