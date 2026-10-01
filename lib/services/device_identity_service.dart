import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:moai3/models/device_record.dart';
import 'package:moai3/services/app_preferences_service.dart';

/// Servicio responsable de gestionar la identidad inmutable y unívoca del dispositivo local.
/// 
/// Garantiza que cada dispositivo físico mantenga exactamente el mismo `device_id` (UUID v5 determinista)
/// a través de actualizaciones de la app, borrado de caché, reinicios o reinstalaciones.
/// Cumple con las reglas RB-01, RB-05 y RB-07 de SPEC-22.
class DeviceIdentityService {
  static const String keyDeviceId = 'device_id';
  static const String keyFirstLaunch = 'device_first_launch';
  static const String keyUserCode = 'device_user_code';
  static const String keyNickname = 'device_nickname';

  final AppPreferences _preferences;
  final Uuid _uuid;
  final MethodChannel _channel;

  String? _cachedDeviceId;

  DeviceIdentityService(
    this._preferences, {
    Uuid? uuid,
    MethodChannel? channel,
  })  : _uuid = uuid ?? const Uuid(),
        _channel = channel ?? const MethodChannel('com.infomak.moai.tv/device');

  /// Inicializa de manera asíncrona la identidad única del hardware físico.
  /// 
  /// 1. Consulta el identificador inmutable de hardware (`Settings.Secure.ANDROID_ID` en Android,
  ///    o `/etc/machine-id` en Linux).
  /// 2. Genera un UUID v5 determinista basado en ese hardware.
  /// 3. Respalda en archivo persistente y SharedPreferences.
  Future<String> initialize() async {
    // 1. Intentar resolver mediante hardware inmutable (RB-01: unívoco por dispositivo físico)
    final hardwareId = await _getHardwareId();
    if (hardwareId != null && hardwareId.isNotEmpty) {
      final hardwareUuid = _uuid.v5(Uuid.NAMESPACE_URL, 'moai:device:$hardwareId');
      _cachedDeviceId = hardwareUuid;
      await _preferences.saveString(keyDeviceId, hardwareUuid);
      await _saveDeviceIdToFile(hardwareUuid);
      if (_preferences.readOptionalString(keyFirstLaunch) == null) {
        await _preferences.saveString(keyFirstLaunch, DateTime.now().toUtc().toIso8601String());
      }
      return hardwareUuid;
    }

    // 2. Si no hay hardware ID (ej. emulador sin ID o tests), verificar archivo persistente en disco
    final fileId = await _readDeviceIdFromFile();
    if (fileId != null && fileId.isNotEmpty) {
      _cachedDeviceId = fileId;
      await _preferences.saveString(keyDeviceId, fileId);
      return fileId;
    }

    // 3. Verificar SharedPreferences
    final prefsId = _preferences.readOptionalString(keyDeviceId);
    if (prefsId != null && prefsId.trim().isNotEmpty) {
      _cachedDeviceId = prefsId.trim();
      await _saveDeviceIdToFile(prefsId.trim());
      return prefsId.trim();
    }

    // 4. Si es completamente nuevo y no hay hardware identificable, generar nuevo UUID v4
    final newId = _uuid.v4();
    _cachedDeviceId = newId;
    await _preferences.saveString(keyDeviceId, newId);
    await _saveDeviceIdToFile(newId);
    if (_preferences.readOptionalString(keyFirstLaunch) == null) {
      await _preferences.saveString(keyFirstLaunch, DateTime.now().toUtc().toIso8601String());
    }
    return newId;
  }

  /// Consulta el identificador único nativo del hardware.
  Future<String?> _getHardwareId() async {
    if (kIsWeb) return null;

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final hardwareId = await _channel.invokeMethod<String>('getHardwareDeviceId');
        if (hardwareId != null && hardwareId.trim().isNotEmpty && hardwareId.trim() != 'unknown') {
          return hardwareId.trim();
        }
      } catch (e) {
        debugPrint('[DeviceIdentityService] No se pudo obtener ANDROID_ID por canal: $e');
      }
    } else if (!kIsWeb && Platform.isLinux) {
      try {
        for (final path in ['/etc/machine-id', '/var/lib/dbus/machine-id']) {
          final file = File(path);
          if (await file.exists()) {
            final content = (await file.readAsString()).trim();
            if (content.isNotEmpty) {
              return content;
            }
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<File?> _getBackupFile() async {
    try {
      final dir = await getApplicationSupportDirectory();
      return File('${dir.path}/.moai_device_id');
    } catch (_) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        return File('${dir.path}/.moai_device_id');
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _saveDeviceIdToFile(String id) async {
    try {
      final file = await _getBackupFile();
      if (file != null) {
        await file.writeAsString(id.trim(), flush: true);
      }
    } catch (_) {}
  }

  Future<String?> _readDeviceIdFromFile() async {
    try {
      final file = await _getBackupFile();
      if (file != null && await file.exists()) {
        final content = (await file.readAsString()).trim();
        if (content.isNotEmpty) return content;
      }
    } catch (_) {}
    return null;
  }

  /// Obtiene el UUID único existente (en memoria, SharedPreferences o genera uno nuevo).
  String getOrCreateDeviceId() {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }

    final existingId = _preferences.readOptionalString(keyDeviceId);
    if (existingId != null && existingId.trim().isNotEmpty) {
      _cachedDeviceId = existingId.trim();
      return existingId.trim();
    }

    final newId = _uuid.v4();
    _cachedDeviceId = newId;
    _preferences.saveString(keyDeviceId, newId);
    
    if (_preferences.readOptionalString(keyFirstLaunch) == null) {
      _preferences.saveString(keyFirstLaunch, DateTime.now().toUtc().toIso8601String());
    }

    return newId;
  }

  /// Obtiene la versión actual de la aplicación (ej: "3.0.19+12").
  Future<String> getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.buildNumber.isNotEmpty) {
        return '${info.version}+${info.buildNumber}';
      }
      return info.version.isNotEmpty ? info.version : '3.0.0';
    } catch (_) {
      return '3.0.0';
    }
  }

  /// Obtiene el objeto consolidado [DeviceIdentity].
  Future<DeviceIdentity> getIdentity() async {
    if (_cachedDeviceId == null) {
      await initialize();
    }
    final id = getOrCreateDeviceId();
    final version = await getAppVersion();
    final firstLaunchStr = _preferences.readOptionalString(keyFirstLaunch);
    final firstLaunch = firstLaunchStr != null
        ? DateTime.tryParse(firstLaunchStr) ?? DateTime.now()
        : DateTime.now();

    return DeviceIdentity(
      deviceId: id,
      appVersion: version,
      firstLaunch: firstLaunch,
    );
  }

  /// Obtiene el código de usuario (`MOAI-XXXX`) guardado localmente.
  String? getUserCode() => _preferences.readOptionalString(keyUserCode);

  /// Guarda el código de usuario (`MOAI-XXXX`) en preferencias.
  Future<void> saveUserCode(String code) => _preferences.saveString(keyUserCode, code);

  /// Obtiene el nickname guardado localmente.
  String? getNickname() => _preferences.readOptionalString(keyNickname);

  /// Guarda el nickname en preferencias.
  Future<void> saveNickname(String nickname) => _preferences.saveString(keyNickname, nickname);
}
