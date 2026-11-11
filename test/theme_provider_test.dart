import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/theme_provider.dart';
import 'package:moai3/theme/moai_accent_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider', () {
    test('arranca en claro (sin preferencias)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.init();
      final themeProvider = ThemeProvider(prefs);

      expect(themeProvider.darkMode, isFalse);
      expect(themeProvider.themeMode, ThemeMode.light);
    });

    test('no lee la preferencia vieja (dark_mode valía true)', () async {
      SharedPreferences.setMockInitialValues({'flutter.dark_mode': true});
      final prefs = await AppPreferences.init();
      final themeProvider = ThemeProvider(prefs);

      expect(themeProvider.darkMode, isFalse);

      await themeProvider.setDarkMode(true);
      expect(ThemeProvider(prefs).darkMode, isTrue);
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

    test(
      'setAutoAccent toggles preference and restores manual color on disable',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await AppPreferences.init();
        final themeProvider = ThemeProvider(prefs);

        // Set manual color index 3
        await themeProvider.setAccentColorIndex(3);
        expect(themeProvider.accentColorIndex, 3);

        // Turn on auto accent
        await themeProvider.setAutoAccent(true);
        expect(themeProvider.autoAccent, isTrue);
        expect(
          themeProvider.accentColorIndex,
          inInclusiveRange(0, MoaiAccentColors.seeds.length - 1),
        );

        // Turn off auto accent, should restore manual color index 3
        await themeProvider.setAutoAccent(false);
        expect(themeProvider.autoAccent, isFalse);
        expect(themeProvider.accentColorIndex, 3);
      },
    );

    test('cold start with autoAccent true generates random color', () async {
      SharedPreferences.setMockInitialValues({
        'auto_accent_color': true,
        'accent_color_index': 5,
      });
      final prefs = await AppPreferences.init();
      final themeProvider = ThemeProvider(prefs);

      expect(themeProvider.autoAccent, isTrue);
      expect(
        themeProvider.accentColorIndex,
        inInclusiveRange(0, MoaiAccentColors.seeds.length - 1),
      );
    });

    test('el índice de la lista vieja sigue siendo el mismo color', () async {
      // Vieja: 9 = Rojo (con Esmeralda y Ámbar antes); en la nueva es el 7.
      SharedPreferences.setMockInitialValues({'accent_color_index': 9});
      final prefs = await AppPreferences.init();
      final themeProvider = ThemeProvider(prefs);

      expect(themeProvider.accentColorIndex, 7);
      expect(themeProvider.accentSeed, const Color(0xFFE53935));
      // Queda guardado en la clave nueva.
      expect(prefs.readOptionalInt('accent_color_index_v2'), 7);
    });

    test(
      'Esmeralda y Ámbar de la lista vieja pasan a Verde y Naranja',
      () async {
        SharedPreferences.setMockInitialValues({'accent_color_index': 4});
        final emerald = ThemeProvider(await AppPreferences.init());
        expect(
          MoaiAccentColors.labelKeys[emerald.accentColorIndex],
          'settings_accent_green',
        );

        SharedPreferences.setMockInitialValues({'accent_color_index': 8});
        final amber = ThemeProvider(await AppPreferences.init());
        expect(
          MoaiAccentColors.labelKeys[amber.accentColorIndex],
          'settings_accent_orange',
        );
      },
    );
  });
}
