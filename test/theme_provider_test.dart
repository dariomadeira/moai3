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

    test('defaults to autoAccent false', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.init();
      final themeProvider = ThemeProvider(prefs);

      expect(themeProvider.autoAccent, isFalse);
    });

    test('setAutoAccent toggles preference and restores manual color on disable', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.init();
      final themeProvider = ThemeProvider(prefs);

      // Set manual color index 3
      await themeProvider.setAccentColorIndex(3);
      expect(themeProvider.accentColorIndex, 3);

      // Turn on auto accent
      await themeProvider.setAutoAccent(true);
      expect(themeProvider.autoAccent, isTrue);
      expect(themeProvider.accentColorIndex, inInclusiveRange(0, 11));

      // Turn off auto accent, should restore manual color index 3
      await themeProvider.setAutoAccent(false);
      expect(themeProvider.autoAccent, isFalse);
      expect(themeProvider.accentColorIndex, 3);
    });

    test('cold start with autoAccent true generates random color', () async {
      SharedPreferences.setMockInitialValues({
        'auto_accent_color': true,
        'accent_color_index': 5,
      });
      final prefs = await AppPreferences.init();
      final themeProvider = ThemeProvider(prefs);

      expect(themeProvider.autoAccent, isTrue);
      expect(themeProvider.accentColorIndex, inInclusiveRange(0, 11));
    });
  });
}
