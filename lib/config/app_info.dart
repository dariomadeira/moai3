import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moai3/platform/platform_channels.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Datos de la app y del equipo, leídos una sola vez al arrancar (SPEC-50 §2.8).
abstract final class AppInfo {
  static String version = '3.0.0';
  static String buildNumber = '';

  /// RAM total en MB; 2048 si el canal nativo no responde (desktop, tests).
  static int totalRamMb = 2048;

  /// `3.0.19+12` si hay número de build; si no, solo la versión.
  static String get fullVersion =>
      buildNumber.isEmpty ? version : '$version+$buildNumber';

  static Future<void> initialize() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) version = info.version;
      buildNumber = info.buildNumber;
    } catch (e) {
      debugPrint('[AppInfo] PackageInfo no disponible: $e');
    }
    if (!Platform.isAndroid) return;
    try {
      final ram = await PlatformChannels.device.invokeMethod<int>(
        'getTotalRamMb',
      );
      if (ram != null && ram > 0) totalRamMb = ram;
    } catch (e) {
      debugPrint('[AppInfo] RAM no disponible: $e');
    }
  }
}
