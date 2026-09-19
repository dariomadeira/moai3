import 'package:flutter/material.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';

/// Helper global para mostrar notificaciones estilo Pill unificado en toda la app.
class NotificationHelper {
  static GlobalKey<ScaffoldMessengerState>? _scaffoldMessengerKey;
  static BuildContext? _context;

  /// Inicializa el helper con la GlobalKey del ScaffoldMessenger
  static void initialize(GlobalKey<ScaffoldMessengerState> key) {
    _scaffoldMessengerKey = key;
  }

  /// Actualiza el contexto para acceder al tema actual
  static void updateContext(BuildContext context) {
    _context = context;
  }

  /// Muestra un snackbar genérico estilo pill
  static void show({
    required String message,
    IconData? icon,
    Color? iconColor,
    Duration duration = MoaiSnackBar.defaultDuration,
    double bottomMargin = MoaiSnackBar.defaultBottomMargin,
  }) {
    final messenger = _scaffoldMessengerKey?.currentState;
    if (messenger == null) {
      debugPrint('⚠️ NotificationHelper: ScaffoldMessenger no está disponible');
      return;
    }

    try {
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        MoaiSnackBar.buildSnackBar(
          context: _context ?? _scaffoldMessengerKey?.currentContext,
          message: message,
          icon: icon,
          iconColor: iconColor,
          bottomMargin: bottomMargin,
          duration: duration,
        ),
      );
    } catch (e) {
      debugPrint('🔔 NotificationHelper: Error al mostrar snackbar - $e');
    }
  }

  /// Muestra un snackbar de error
  static void showError(String message) {
    show(
      message: message,
      icon: Icons.error_outline,
      iconColor: const Color(0xFFF87171),
      duration: const Duration(seconds: 3),
    );
  }

  /// Muestra un snackbar de éxito
  static void showSuccess(String message) {
    show(
      message: message,
      icon: Icons.check_circle_outline,
      iconColor: const Color(0xFF4ADE80),
      duration: const Duration(seconds: 2),
    );
  }

  /// Muestra un snackbar informativo
  static void showInfo(String message) {
    show(
      message: message,
      icon: Icons.info_outline,
      iconColor: const Color(0xFF60A5FA),
      duration: const Duration(seconds: 2),
    );
  }

  /// Muestra un snackbar de advertencia
  static void showWarning(String message) {
    show(
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFFBBF24),
      duration: const Duration(seconds: 3),
    );
  }
}

