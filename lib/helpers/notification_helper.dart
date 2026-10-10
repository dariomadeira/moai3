import 'package:flutter/material.dart';
import 'package:moai3/theme/app_icons.dart';
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
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? show({
    required String message,
    dynamic icon,
    Color? iconColor,
    String? hint,
    VoidCallback? onAction,
    Duration duration = MoaiSnackBar.defaultDuration,
    double bottomMargin = MoaiSnackBar.defaultBottomMargin,
  }) {
    final messenger = _scaffoldMessengerKey?.currentState;
    if (messenger == null) {
      debugPrint('⚠️ NotificationHelper: ScaffoldMessenger no está disponible');
      return null;
    }

    try {
      messenger.removeCurrentSnackBar();
      return messenger.showSnackBar(
        MoaiSnackBar.buildSnackBar(
          context: _scaffoldMessengerKey?.currentContext ?? _context,
          message: message,
          icon: icon,
          iconColor: iconColor,
          hint: hint,
          onAction: onAction,
          bottomMargin: bottomMargin,
          duration: duration,
        ),
      );
    } catch (e) {
      debugPrint('🔔 NotificationHelper: Error al mostrar snackbar - $e');
      return null;
    }
  }

  /// Oculta el snackbar actual animadamente si existe
  static void hideCurrent() {
    _scaffoldMessengerKey?.currentState?.hideCurrentSnackBar();
  }

  /// Remueve de inmediato el snackbar actual
  static void removeCurrent() {
    _scaffoldMessengerKey?.currentState?.removeCurrentSnackBar();
  }

  /// Muestra un snackbar de error
  static void showError(String message) {
    show(
      message: message,
      icon: AppIcons.error,
      duration: const Duration(seconds: 3),
    );
  }

  /// Muestra un snackbar de éxito
  static void showSuccess(String message) {
    show(
      message: message,
      icon: AppIcons.check,
      duration: const Duration(seconds: 2),
    );
  }

  /// Muestra un snackbar informativo
  static void showInfo(String message) {
    show(
      message: message,
      icon: AppIcons.info,
      duration: const Duration(seconds: 2),
    );
  }

  /// Muestra un snackbar de advertencia
  static void showWarning(String message) {
    show(
      message: message,
      icon: AppIcons.warning,
      duration: const Duration(seconds: 3),
    );
  }
}

