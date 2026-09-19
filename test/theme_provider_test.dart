import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider', () {
    test('defaults to dark mode on first install (empty preferences)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.init();
      final themeProvider = ThemeProvider(prefs);

      expect(themeProvider.darkMode, isTrue);
      expect(themeProvider.themeMode, ThemeMode.dark);
    });

    test('saves and loads light mode preference', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.init();
      final themeProvider = ThemeProvider(prefs);

      await themeProvider.setDarkMode(false);

      expect(themeProvider.darkMode, isFalse);
      expect(themeProvider.themeMode, ThemeMode.light);

      // Re-instance ThemeProvider to simulate app restart
      final reloadedProvider = ThemeProvider(prefs);
      expect(reloadedProvider.darkMode, isFalse);
      expect(reloadedProvider.themeMode, ThemeMode.light);
    });
  });
}
