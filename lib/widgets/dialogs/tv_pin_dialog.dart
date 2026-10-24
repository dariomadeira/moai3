import 'dart:math';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/theme/moai_icons.dart';

part 'tv_pin/tv_pin_input.dart';
part 'tv_pin/tv_pin_views.dart';

/// Curva sinusoidal para sacudida suave (shake) ante errores de validación de PIN.
class _PinShakeCurve extends Curve {
  const _PinShakeCurve();

  @override
  double transformInternal(double t) {
    return sin(t * pi * 4);
  }
}

/// Modo de operación del diálogo de PIN.
enum TvPinDialogMode {
  /// Ingreso y verificación simple de PIN (ej. desbloquear sesión).
  verify,

  /// Configuración de nuevo PIN (Paso 1: Crear -> Paso 2: Confirmar).
  create,

  /// Cambio de PIN (Paso 1: Actual -> Paso 2: Nuevo -> Paso 3: Confirmar).
  change,
}

/// Diálogo modal TV para entrada, validación y configuración fluida de PIN parental (4 dígitos).
///
/// Implementa una máquina de estados interna para flujos multi-paso sin recargar ni
/// cerrar el diálogo entre pasos, evitando pantallazos.
/// Diseñado con estética M3 Expressive alineada al teclado en pantalla de la app.
class TvPinDialog extends StatefulWidget {
  final TvPinDialogMode mode;
  final String? customTitle;
  final String? customSubtitle;
  final TvSettingsProvider? tvSettings;
  final Future<bool> Function(String pin)? onValidate;

  const TvPinDialog({
    super.key,
    this.mode = TvPinDialogMode.verify,
    this.customTitle,
    this.customSubtitle,
    this.tvSettings,
    this.onValidate,
  });

  /// Muestra el diálogo en modo verificación simple o captura de 4 dígitos.
  static Future<String?> show(
    BuildContext context, {
    String? title,
    String? subtitle,
    Future<bool> Function(String pin)? onValidate,
  }) {
    return showGeneralDialog<String?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      pageBuilder: (context, _, _) => TvPinDialog(
        customTitle: title,
        customSubtitle: subtitle,
        onValidate: onValidate,
      ),
    );
  }

  /// Flujo para desbloquear contenido adulto en la sesión actual.
  static Future<bool> unlockAdultSession(
    BuildContext context,
    TvSettingsProvider tvSettings,
  ) async {
    if (!tvSettings.hasParentalPin) {
      final created = await setupNewPin(context, tvSettings);
      if (created) {
        tvSettings.unlockAdultForSession();
        if (context.mounted) {
          MoaiSnackBar.show(
            context,
            message: LocaleKeys.parental_adult_unlocked.tr(),
            icon: MoaiIcons.lockOpen,
          );
        }
        return true;
      }
      return false;
    }

    final success = await showGeneralDialog<bool?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      pageBuilder: (context, _, _) => TvPinDialog(
        tvSettings: tvSettings,
        customTitle: LocaleKeys.parental_pin_title_enter.tr(),
        customSubtitle: LocaleKeys.settings_tv_adult_content_desc.tr(),
      ),
    );

    if (success == true && context.mounted) {
      tvSettings.unlockAdultForSession();
      MoaiSnackBar.show(
        context,
        message: LocaleKeys.parental_adult_unlocked.tr(),
        icon: MoaiIcons.lockOpen,
      );
      return true;
    }
    return false;
  }

  /// Flujo integrado para crear un nuevo PIN (Paso 1: Crear, Paso 2: Confirmar en el mismo modal).
  static Future<bool> setupNewPin(
    BuildContext context,
    TvSettingsProvider tvSettings,
  ) async {
    final success = await showGeneralDialog<bool?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      pageBuilder: (context, _, _) => TvPinDialog(
        mode: TvPinDialogMode.create,
        tvSettings: tvSettings,
      ),
    );

    if (success == true && context.mounted) {
      MoaiSnackBar.show(
        context,
        message: LocaleKeys.parental_pin_created_success.tr(),
        icon: MoaiIcons.checkCircle,
      );
      return true;
    }
    return false;
  }

  /// Flujo integrado para cambiar el PIN existente (Paso 1: Actual, Paso 2: Nuevo, Paso 3: Confirmar).
  static Future<bool> changePin(
    BuildContext context,
    TvSettingsProvider tvSettings,
  ) async {
    if (!tvSettings.hasParentalPin) {
      return setupNewPin(context, tvSettings);
    }

    final success = await showGeneralDialog<bool?>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      pageBuilder: (context, _, _) => TvPinDialog(
        mode: TvPinDialogMode.change,
        tvSettings: tvSettings,
      ),
    );

    if (success == true && context.mounted) {
      MoaiSnackBar.show(
        context,
        message: LocaleKeys.parental_pin_changed_success.tr(),
        icon: MoaiIcons.checkCircle,
      );
      return true;
    }
    return false;
  }

  @override
  State<TvPinDialog> createState() => _TvPinDialogState();
}

class _TvPinDialogState extends State<TvPinDialog>
    with SingleTickerProviderStateMixin {
  String _digits = '';
  String? _errorMessage;
  bool _validating = false;

  // Control de pasos internos
  int _currentStep = 1;
  String _stagedPin = '';

  // Animación de sacudida (shake)
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  // Matriz de FocusNodes 4 filas x 3 columnas para navegación D-Pad 100% determinística
  late final List<List<FocusNode>> _focusGrid;
  final FocusNode _cancelBtnFocus = FocusNode(debugLabel: 'pin_dialog_cancel');

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: const _PinShakeCurve(),
      ),
    );

    _focusGrid = List.generate(
      4,
      (r) => List.generate(
        3,
        (c) => FocusNode(debugLabel: 'pin_key_${r}_$c'),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Enfocar la tecla "1" (0, 0)
        _focusGrid[0][0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _cancelBtnFocus.dispose();
    for (final row in _focusGrid) {
      for (final node in row) {
        node.dispose();
      }
    }
    super.dispose();
  }

  int get _totalSteps {
    switch (widget.mode) {
      case TvPinDialogMode.verify:
        return 1;
      case TvPinDialogMode.create:
        return 2;
      case TvPinDialogMode.change:
        return 3;
    }
  }

  String get _currentTitle {
    switch (widget.mode) {
      case TvPinDialogMode.verify:
        return widget.customTitle ?? LocaleKeys.parental_pin_title_enter.tr();
      case TvPinDialogMode.create:
        return _currentStep == 1
            ? LocaleKeys.parental_pin_title_create.tr()
            : LocaleKeys.parental_pin_title_confirm.tr();
      case TvPinDialogMode.change:
        if (_currentStep == 1) return LocaleKeys.parental_pin_title_current.tr();
        if (_currentStep == 2) return LocaleKeys.parental_pin_title_create.tr();
        return LocaleKeys.parental_pin_title_confirm.tr();
    }
  }

  String get _currentSubtitle {
    switch (widget.mode) {
      case TvPinDialogMode.verify:
        return widget.customSubtitle ?? LocaleKeys.parental_pin_create_subtitle.tr();
      case TvPinDialogMode.create:
        return _currentStep == 1
            ? LocaleKeys.parental_pin_create_subtitle.tr()
            : LocaleKeys.parental_pin_confirm_subtitle.tr();
      case TvPinDialogMode.change:
        if (_currentStep == 1) return LocaleKeys.parental_pin_current_subtitle.tr();
        if (_currentStep == 2) return LocaleKeys.parental_pin_create_subtitle.tr();
        return LocaleKeys.parental_pin_confirm_subtitle.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final stepBadge = _totalSteps > 1
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              LocaleKeys.parental_pin_step.tr(args: ['$_currentStep', '$_totalSteps']),
              style: MoaiText.body(
                context,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.onTertiaryContainer,
              ),
            ),
          )
        : null;

    return Focus(
      onKeyEvent: _handleGlobalKeyEvent,
      child: TvDialog(
        width: 440,
        icon: MoaiIcons.lock,
        titleWidget: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _currentTitle,
            key: ValueKey('title_$_currentStep'),
            style: MoaiText.display(
              context,
              fontSize: 18,
              color: scheme.onSurface,
            ),
          ),
        ),
        subtitleWidget: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            _currentSubtitle,
            key: ValueKey('sub_$_currentStep'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(
              context,
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        trailingHeader: stepBadge != null
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey('badge_$_currentStep'),
                  child: stepBadge,
                ),
              )
            : null,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),

            // Cajas/dígitos de PIN con animación de sacudida
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: _buildPinBoxes(scheme),
            ),

            // Espacio reservado para mensajes de error (evita saltos verticales de layout)
            Container(
              height: 24,
              alignment: Alignment.center,
              child: _errorMessage != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          MoaiIcons.error,
                          size: 13,
                          color: scheme.error,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _errorMessage!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MoaiText.body(
                              context,
                              fontSize: 11.5,
                              color: scheme.error,
                            ),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),

            const SizedBox(height: 2),

            // Teclado numérico virtual 3x4 integrado con navegación D-Pad
            _buildKeypad(scheme),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TvDialogButton(
            focusNode: _cancelBtnFocus,
            label: LocaleKeys.common_cancel.tr(),
            onKeyUp: () => _focusGrid[3][1].requestFocus(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// `setState` para los `part` (es `@protected`).
  void _update(VoidCallback fn) => setState(fn);
}
