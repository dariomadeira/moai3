import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';

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
  static const _deviceChannel = MethodChannel('com.infomak.moai.tv/device');

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
    SystemNavigator.pop();
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

    final nowAfterIntercept = DateTime.now();
    if (_lastBackTime != null &&
        nowAfterIntercept.difference(_lastBackTime!) < widget.exitWindow) {
      _lastBackTime = null;
      _exitApp();
      return;
    }

    _lastBackTime = nowAfterIntercept;
    MoaiSnackBar.show(
      context,
      message: 'home_exit_double_back'.tr(),
      icon: Icons.exit_to_app_rounded,
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

