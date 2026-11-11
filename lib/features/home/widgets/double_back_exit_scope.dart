import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/platform/platform_channels.dart';
import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Margen inferior del snack de salida (zona segura TV / overscan).
const _exitSnackBottomMargin = 56.0;

/// Intercepta back: si devuelve `true`, el evento no cuenta para salir de la app.
typedef BackInterceptCallback = bool Function();

class DoubleBackExitScope extends StatefulWidget {
  final Widget child;
  final BackInterceptCallback? onBackIntercept;
  final Duration exitWindow;

  const DoubleBackExitScope({
    super.key,
    required this.child,
    this.onBackIntercept,
    this.exitWindow = const Duration(seconds: 2),
  });

  @override
  State<DoubleBackExitScope> createState() => DoubleBackExitScopeState();
}

class DoubleBackExitScopeState extends State<DoubleBackExitScope> {
  static const _deviceChannel = PlatformChannels.device;

  DateTime? _lastBackTime;
  DateTime? _lastHandledTime;

  Future<void> _exitApp() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    if (Platform.isAndroid) {
      try {
        await _deviceChannel.invokeMethod<void>('finishApp');
        return;
      } catch (_) {
        // Fallback si el canal nativo no está disponible.
      }
    }
    unawaited(SystemNavigator.pop());
  }

  void handleBack() {
    final now = DateTime.now();
    if (_lastHandledTime != null &&
        now.difference(_lastHandledTime!) < const Duration(milliseconds: 150)) {
      return;
    }
    _lastHandledTime = now;

    if (widget.onBackIntercept?.call() == true) {
      _lastBackTime = null;
      return;
    }

    _confirmExit(LocaleKeys.home_exit_double_back.tr());
  }

  /// Botón de salir del rail: el primer toque avisa con el snack y el
  /// segundo (dentro de [DoubleBackExitScope.exitWindow]) sale. Comparte la
  /// ventana con atrás: atrás + OK también sale.
  void requestExit() => _confirmExit(LocaleKeys.home_exit_double_ok.tr());

  void _confirmExit(String message) {
    final now = DateTime.now();
    if (_lastBackTime != null &&
        now.difference(_lastBackTime!) < widget.exitWindow) {
      _lastBackTime = null;
      _exitApp();
      return;
    }

    _lastBackTime = now;
    MoaiSnackBar.show(
      context,
      message: message,
      icon: MoaiIcons.exitApp,
      bottomMargin: _exitSnackBottomMargin,
      duration: widget.exitWindow,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) handleBack();
      },
      child: widget.child,
    );
  }
}
