import 'package:flutter/material.dart';

extension MoaiThemeContext on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
}

/// Tipografía Moai, local en `assets/fonts`.
/// REDISEÑO (2026-10-30): Varela Round para todo, elegida por el usuario
/// entre las redondeadas libres (Cera Round, la de hugeicons.com, es paga).
/// Tiene un solo peso: títulos y negritas las sintetiza Flutter. ANTES (a
/// limpiar si se confirma): M PLUS Rounded 1c, Onest y Unbounded.
abstract final class MoaiText {
  static const String bodyFamily = 'VarelaRound';

  /// Títulos chicos (paneles, diálogos).
  static const String displayFamily = 'VarelaRound';

  /// Títulos grandes: saludo y reloj del Inicio, títulos de tarjetas,
  /// pantallas y categorías. Hoy la misma familia que el resto.
  static const String headlineFamily = 'VarelaRound';

  /// Cuánto bajar un texto para que se vea centrado junto a un ícono.
  /// Varela Round dibuja números y mayúsculas por encima del centro de su
  /// caja (medido: 0,035 em en "7.7" y "2022", 0,05 em con minúsculas); el
  /// ícono sí va centrado, así que sin esto el texto queda alto.
  static double opticalCenterShift(double fontSize) => fontSize * 0.04;

  /// Desde este tamaño un título va con [headlineFamily].
  static const double headlineMinSize = 20;

  /// Un título. Con [fontSize] de [headlineMinSize] o más va con Unbounded;
  /// [headline] lo fuerza (p. ej. títulos de categoría más chicos).
  static TextStyle display(
    BuildContext context, {
    Color? color,
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    double? height,
    double? letterSpacing,
    bool? headline,
  }) {
    final big = headline ?? fontSize >= headlineMinSize;
    return TextStyle(
      fontFamily: big ? headlineFamily : displayFamily,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle body(
    BuildContext context, {
    Color? color,
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w600,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: bodyFamily,
      color: color ?? Theme.of(context).colorScheme.onSurface,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextTheme textTheme(ColorScheme scheme) {
    final base = ThemeData(brightness: scheme.brightness).textTheme;
    return base.apply(
      fontFamily: bodyFamily,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
  }
}
