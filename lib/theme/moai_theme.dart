import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_palette.dart';
import 'package:moai3/theme/moai_text.dart';

/// Los temas de la app. Viven acá (y no en `MoaiApp`) para que los tests
/// dibujen con exactamente el mismo tema que el TV.
abstract final class MoaiTheme {
  /// REDISEÑO: la paleta de Cleanly (getcleanly.vercel.app): tinta casi negra
  /// sobre superficies claras y violeta de apoyo. El acento es el color de
  /// resalte elegido en Ajustes (por defecto el azul de Cleanly, `--blue`).
  static ThemeData light(Color seed) =>
      build(lightScheme(seed), MoaiPalette.light);

  /// REDISEÑO oscuro (2026-11-10): la misma paleta de Cleanly de noche,
  /// estilo visionOS oscuro: fondo casi negro azulado, tinta clara y el
  /// mismo acento.
  static ThemeData dark(Color seed) =>
      build(darkScheme(seed), MoaiPalette.dark);

  static ColorScheme lightScheme(Color seed) =>
      ColorScheme.fromSeed(seedColor: seed).copyWith(
        primary: seed,
        // Sobre un acento claro (ámbar, cian…) el blanco no se lee.
        onPrimary: ThemeData.estimateBrightnessForColor(seed) == Brightness.dark
            ? Colors.white
            : Colors.black,
        tertiary: const Color(0xFF8A5CFF), // --violet
        onTertiary: Colors.white,
        surface: const Color(0xFFF6F5F9), // --paper
        surfaceContainer: const Color(0xFFF2F3F6), // --paper-2
        onSurface: const Color(0xFF0F1218), // --ink
        // --ink-3, un poco más oscuro (antes #5B6270): los textos secundarios
        // se leían lavados sobre el cristal.
        onSurfaceVariant: const Color(0xFF474D59),
        outline: const Color(0xFF5B6270),
        outlineVariant: const Color(0xFFE2E5EA), // --line
      );

  static ColorScheme darkScheme(Color seed) {
    // El acento, un poco más claro: tal cual, el texto en ese color (enlaces,
    // la segunda palabra de los títulos) no se leía sobre lo oscuro.
    final primary = Color.lerp(seed, Colors.white, 0.2)!;
    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      onPrimary:
          ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
          ? Colors.white
          : Colors.black,
      tertiary: const Color(0xFF9F82FF), // --violet, un poco más claro
      onTertiary: Colors.white,
      surface: const Color(0xFF15171D),
      surfaceContainer: const Color(0xFF101217),
      onSurface: const Color(0xFFECEEF3),
      onSurfaceVariant: const Color(0xFFA9AFBC),
      outline: const Color(0xFF8A91A0),
      outlineVariant: const Color(0xFF2A2E37),
    );
  }

  /// Lo común a todos los temas, armado sobre [scheme]; [palette], la del
  /// cristal ([MoaiPalette]) de ese modo.
  static ThemeData build(ColorScheme scheme, MoaiPalette palette) {
    return ThemeData(
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surfaceContainer,
      useMaterial3: true,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: MoaiFadePageTransitionsBuilder(),
          TargetPlatform.iOS: MoaiFadePageTransitionsBuilder(),
          TargetPlatform.windows: MoaiFadePageTransitionsBuilder(),
          TargetPlatform.linux: MoaiFadePageTransitionsBuilder(),
          TargetPlatform.macOS: MoaiFadePageTransitionsBuilder(),
        },
      ),
      fontFamily: MoaiText.bodyFamily,
      textTheme: MoaiText.textTheme(scheme),
      // Grosor del trazo de todos los íconos (fuente variable de
      // hugeicons_plus: 0,5 a 3,0). REDISEÑO: 1,5, el de diseño de
      // HugeIcons; antes 1,2 (se veían finos).
      iconTheme: const IconThemeData(weight: 1.5),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
      ),
      // Regla general: los indicadores de carga (los circulares) son
      // grises, nunca del acento. Los que no dicen color toman éste.
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.onSurfaceVariant,
      ),
      extensions: [palette],
    );
  }
}

/// Transición de pantalla por fundido directo:
/// - Sin desplazamiento lateral (sin movimiento 'de costado').
/// - La pantalla saliente permanece debajo hasta ser cubierta por completo,
///   eliminando destellos del fondo de la ventana.
class MoaiFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const MoaiFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      child: child,
    );
  }
}
