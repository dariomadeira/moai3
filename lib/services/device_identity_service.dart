import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:moai3/models/device_record.dart';
import 'package:moai3/services/app_preferences_service.dart';

/// Servicio responsable de gestionar la identidad inmutable del dispositivo local.
/// Cumple con las reglas RB-01, RB-05 y RB-07 de SPEC-22.
class DeviceIdentityService {
  static const String keyDeviceId = 'device_id';
  static const String keyFirstLaunch = 'device_first_launch';

  final AppPreferences _preferences;
  final Uuid _uuid;

  DeviceIdentityService(
    this._preferences, {
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  /// Obtiene el UUID único existente o genera uno nuevo (UUID v4) y lo persiste.
  String getOrCreateDeviceId() {
    final existingId = _preferences.readOptionalString(keyDeviceId);
    if (existingId != null && existingId.trim().isNotEmpty) {
      return existingId.trim();
    }

    final newId = _uuid.v4();
    _preferences.saveString(keyDeviceId, newId);
    
    if (_preferences.readOptionalString(keyFirstLaunch) == null) {
      _preferences.saveString(keyFirstLaunch, DateTime.now().toUtc().toIso8601String());
    }

    return newId;
  }

  /// Obtiene la versión actual de la aplicación (ej: "3.0.16+9").
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
}
