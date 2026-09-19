import 'package:moai3/services/device_memory_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class PlayerConfig {
  static String appVersion = '1.0.0';
  static int totalRamMb = 0;

  static const String modeLabel = 'Motor Kotlin (ExoPlayer nativo)';

  static Future<void> initialize() async {
    totalRamMb = await DeviceMemoryService.getTotalRamMb();
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
    } catch (_) {}
  }
}
