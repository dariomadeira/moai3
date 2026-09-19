import 'package:flutter/material.dart';

extension MoaiThemeContext on BuildContext {
  ColorScheme get scheme => Theme.of(this).colorScheme;

  /// Superficie elevada genérica (equivale a cards/paneles sin palette fija).
  Color get elevatedSurface => scheme.surfaceContainerHigh;
}

/// Tipografía Moai (igual que moaiSmart): Quicksand títulos, Nunito cuerpo.
abstract final class MoaiText {
  static const String bodyFamily = 'Nunito';

  static const String displayFamily = 'Quicksand';

  static TextStyle display(
    BuildContext context, {
    Color? color,
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
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
