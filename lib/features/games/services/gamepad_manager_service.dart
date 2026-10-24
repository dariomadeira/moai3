import 'package:moai3/platform/platform_channels.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';

/// Modelo que describe un Gamepad físico conectado al dispositivo.
class GamepadDeviceInfo {
  final int id;
  final String name;
  final String descriptor;
  final int vendorId;
  final int productId;
  final bool isExternal;

  const GamepadDeviceInfo({
    required this.id,
    required this.name,
    required this.descriptor,
    required this.vendorId,
    required this.productId,
    required this.isExternal,
  });

  factory GamepadDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return GamepadDeviceInfo(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: (map['name'] as String?) ?? LocaleKeys.gamepad_unknown.tr(),
      descriptor: (map['descriptor'] as String?) ?? '',
      vendorId: (map['vendorId'] as num?)?.toInt() ?? 0,
      productId: (map['productId'] as num?)?.toInt() ?? 0,
      isExternal: (map['isExternal'] as bool?) ?? true,
    );
  }
}

/// Servicio singleton/gestor para detectar mandos y gestionar perfiles de control.
class GamepadManagerService extends ChangeNotifier {
  static const MethodChannel _channel =
      PlatformChannels.arcade;

  List<GamepadDeviceInfo> _connectedGamepads = [];
  bool _isLoading = false;

  List<GamepadDeviceInfo> get connectedGamepads => _connectedGamepads;
  bool get hasGamepadConnected => _connectedGamepads.isNotEmpty;
  bool get isLoading => _isLoading;

  Future<void> refreshGamepads() async {
    _isLoading = true;
    notifyListeners();
    try {
      final List<dynamic>? raw =
          await _channel.invokeListMethod('getConnectedGamepads');
      if (raw != null) {
        _connectedGamepads = raw
            .whereType<Map<dynamic, dynamic>>()
            .map(GamepadDeviceInfo.fromMap)
            .toList();
      } else {
        _connectedGamepads = [];
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[GamepadManagerService] Error consultando gamepads: $e');
      }
      _connectedGamepads = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
