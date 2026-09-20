import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TvSettingsProvider - Parental Control', () {
    test('defaults to locked adult and no pin on clean install', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.init();
      final provider = TvSettingsProvider(prefs);

      expect(provider.isAdultUnlocked, isFalse);
      expect(provider.hasParentalPin, isFalse);
      expect(provider.verifyPin('1234'), isFalse);
    });

    test('sets and verifies parental pin', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.init();
      final provider = TvSettingsProvider(prefs);

      await provider.setParentalPin('4321');
      expect(provider.hasParentalPin, isTrue);
      expect(provider.verifyPin('4321'), isTrue);
      expect(provider.verifyPin('0000'), isFalse);
    });

    test('session unlock does not persist across restarts', () async {
      SharedPreferences.setMockInitialValues({
        'parental_pin': '9999',
      });
      final prefs = await AppPreferences.init();
      final provider = TvSettingsProvider(prefs);

      expect(provider.hasParentalPin, isTrue);
      expect(provider.isAdultUnlocked, isFalse);

      provider.unlockAdultForSession();
      expect(provider.isAdultUnlocked, isTrue);

      // Re-instanciar el provider para simular reinicio de la app
      final reloadedProvider = TvSettingsProvider(prefs);
      expect(reloadedProvider.hasParentalPin, isTrue);
      expect(reloadedProvider.isAdultUnlocked, isFalse);
    });

    test('locking adult updates state immediately', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.init();
      final provider = TvSettingsProvider(prefs);

      provider.unlockAdultForSession();
      expect(provider.isAdultUnlocked, isTrue);

      provider.lockAdult();
      expect(provider.isAdultUnlocked, isFalse);
    });
  });
}
