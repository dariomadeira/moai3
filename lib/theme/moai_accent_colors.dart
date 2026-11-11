import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:flutter/material.dart';

/// Semillas M3 para el color primario / de acento.
abstract final class MoaiAccentColors {
  static const List<Color> seeds = [
    // Azul (default): el `--blue` de la paleta de Cleanly del rediseño (antes
    // #4A90D9, más claro).
    Color(0xFF2B4CFF),
    Color(0xFF0D47A1), // Azul Oscuro (Fuerte)
    Color(0xFF00897B), // Teal
    Color(0xFF43A047), // Verde
    Color(0xFF00ACC1), // Cian
    // Naranja: bien oscuro (antes #FB8C00, se lavaba sobre el cristal).
    Color(0xFFC2410C),
    Color(0xFFFF6B6B), // Coral
    Color(0xFFE53935), // Rojo
    Color(0xFFE91E63), // Rosa
    Color(0xFF5C6BC0), // Índigo
    Color(0xFF8E24AA), // Violeta
  ];

  static const List<String> labelKeys = [
    LocaleKeys.settings_accent_blue,
    LocaleKeys.settings_accent_dark_blue,
    LocaleKeys.settings_accent_teal,
    LocaleKeys.settings_accent_green,
    LocaleKeys.settings_accent_cyan,
    LocaleKeys.settings_accent_orange,
    LocaleKeys.settings_accent_coral,
    LocaleKeys.settings_accent_red,
    LocaleKeys.settings_accent_pink,
    LocaleKeys.settings_accent_indigo,
    LocaleKeys.settings_accent_violet,
  ];

  /// Lista vieja (hasta 2026-11-09, con Esmeralda y Ámbar) → la de ahora:
  /// cada índice guardado sigue siendo el mismo color; Esmeralda pasa a Verde
  /// y Ámbar a Naranja.
  static const List<int> legacyIndexMap = [
    0,
    1,
    2,
    3,
    3,
    4,
    5,
    6,
    5,
    7,
    8,
    9,
    10,
  ];

  static int clampIndex(int index) => index.clamp(0, seeds.length - 1);

  static Color seedAt(int index) => seeds[clampIndex(index)];
}
