import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';

/// Sistema unificado de SnackBar estilo Pill para Moai.
/// Centrado, flotante, sin sombras (elevation: 0) y con tipografía consistente.
class MoaiSnackBar {
  static const double defaultSnackWidth = 380.0;
  static const double defaultBottomMargin = 24.0;
  static const Duration defaultDuration = Duration(seconds: 2);

  /// Construye el widget SnackBar con el diseño estándar tipo pill.
  static SnackBar buildSnackBar({
    required BuildContext? context,
    required String message,
    IconData? icon,
    Color? iconColor,
    Color backgroundColor = Colors.black,
    double bottomMargin = defaultBottomMargin,
    Duration duration = defaultDuration,
    double targetWidth = defaultSnackWidth,
  }) {
    final double screenWidth = context != null
        ? MediaQuery.sizeOf(context).width
        : 1920.0;

    final horizontalInset =
        ((screenWidth - targetWidth) / 2).clamp(24.0, screenWidth);

    return SnackBar(
      elevation: 0,
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      margin: EdgeInsets.fromLTRB(
        horizontalInset,
        0,
        horizontalInset,
        bottomMargin,
      ),
      shape: const StadiumBorder(),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: iconColor ?? Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: context != null
                  ? MoaiText.body(
                      context,
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    )
                  : const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      duration: duration,
    );
  }

  /// Muestra un SnackBar genérico estilo pill usando el BuildContext.
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Color? iconColor,
    Color backgroundColor = Colors.black,
    double bottomMargin = defaultBottomMargin,
    Duration duration = defaultDuration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      buildSnackBar(
        context: context,
        message: message,
        icon: icon,
        iconColor: iconColor,
        backgroundColor: backgroundColor,
        bottomMargin: bottomMargin,
        duration: duration,
      ),
    );
  }

  /// Muestra un snackbar de éxito.
  static void showSuccess(
    BuildContext context, {
    required String message,
    double bottomMargin = defaultBottomMargin,
    Duration duration = defaultDuration,
  }) {
    show(
      context,
      message: message,
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF4ADE80),
      bottomMargin: bottomMargin,
      duration: duration,
    );
  }

  /// Muestra un snackbar de error.
  static void showError(
    BuildContext context, {
    required String message,
    double bottomMargin = defaultBottomMargin,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      icon: Icons.error_outline,
      iconColor: const Color(0xFFF87171),
      bottomMargin: bottomMargin,
      duration: duration,
    );
  }

  /// Muestra un snackbar informativo.
  static void showInfo(
    BuildContext context, {
    required String message,
    double bottomMargin = defaultBottomMargin,
    Duration duration = defaultDuration,
  }) {
    show(
      context,
      message: message,
      icon: Icons.info_outline,
      iconColor: const Color(0xFF60A5FA),
      bottomMargin: bottomMargin,
      duration: duration,
    );
  }

  /// Muestra un snackbar de advertencia.
  static void showWarning(
    BuildContext context, {
    required String message,
    double bottomMargin = defaultBottomMargin,
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFFBBF24),
      bottomMargin: bottomMargin,
      duration: duration,
    );
  }
}

