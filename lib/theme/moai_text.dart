import 'package:flutter/material.dart';

extension MoaiThemeContext on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;
}

/// Tipografía Moai, local en `assets/fonts`.
/// Quicksand para todo (2026-11-13), elegida por el usuario: redondeada como
/// Varela Round, la anterior, pero con pesos reales de 400 a 700, así las
/// negritas ya no las sintetiza Flutter. Lo que pide 800 o 900 cae en el 700.
abstract final class MoaiText {
  static const String bodyFamily = 'Quicksand';

  /// Títulos chicos (paneles, diálogos).
  static const String displayFamily = 'Quicksand';

  /// Títulos grandes: saludo y reloj del Inicio, títulos de tarjetas,
  /// pantallas y categorías. Hoy la misma familia que el resto.
  static const String headlineFamily = 'Quicksand';

  /// Cuánto correr un texto (positivo = hacia abajo) para que se vea
  /// centrado junto a un ícono. Quicksand dibuja números y mayúsculas por
  /// debajo del centro de su caja (medido en el archivo: 0,02 a 0,03 em en
  /// "7", "2" y "A", igual en los cuatro pesos); el ícono sí va centrado,
  /// así que sin esto el texto queda bajo.
  static double opticalCenterShift(double fontSize) => fontSize * -0.025;

  /// Piso de lectura en el TV: la app dibuja sobre 960×540 puntos y se mira
  /// a unos 3 m. Ningún texto que haya que leer va por debajo de esto.
  static const double sizeCaption = 12;

  /// Sólo donde [sizeCaption] no entra: las fichas de las grillas de 7
  /// columnas (semana de Agenda y de Descuentos) y el nombre bajo el logo
  /// de un canal. Con 12 los nombres largos pasan a tres renglones.
  static const double sizeDense = 11;

  /// Desde este tamaño un título va con [headlineFamily].
  static const double headlineMinSize = 20;

  /// Un título. Con [fontSize] de [headlineMinSize] o más va con
  /// [headlineFamily];
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
