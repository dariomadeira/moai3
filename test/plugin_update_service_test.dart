import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/plugin_update_service.dart';

void main() {
  group('PluginUpdateService', () {
    test('deriveManifestUrl convierte URLs correctamente', () {
      expect(
        PluginUpdateService.deriveManifestUrl(
          'https://raw.githubusercontent.com/user/repo/main/manifest.json',
        ),
        'https://raw.githubusercontent.com/user/repo/main/manifest.json',
      );

      expect(
        PluginUpdateService.deriveManifestUrl(
          'https://raw.githubusercontent.com/user/repo/main/plugin.dex',
        ),
        'https://raw.githubusercontent.com/user/repo/main/manifest.json',
      );
    });

    test('isNewer detecta versiones semánticas correctamente', () {
      // Casos donde la remota es más nueva
      expect(PluginUpdateService.isNewer('1.3.2', '1.4.0'), isTrue);
      expect(PluginUpdateService.isNewer('1.3.2', '1.3.3'), isTrue);
      expect(PluginUpdateService.isNewer('1.0.0', '2.0.0'), isTrue);
      expect(PluginUpdateService.isNewer('1.3', '1.3.1'), isTrue);
      expect(PluginUpdateService.isNewer('1.9.9', '2.0.0'), isTrue);

      // Casos donde la remota es igual o menor
      expect(PluginUpdateService.isNewer('1.4.0', '1.4.0'), isFalse);
      expect(PluginUpdateService.isNewer('1.4.0', '1.3.2'), isFalse);
      expect(PluginUpdateService.isNewer('2.0.0', '1.9.9'), isFalse);
      expect(PluginUpdateService.isNewer('1.3.1', '1.3.0'), isFalse);
    });
  });
}
