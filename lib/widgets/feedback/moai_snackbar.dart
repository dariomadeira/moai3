import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/services/modal_route_tracker.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// El único snack de Moai: centrado, flotante y de cristal, con un solo
/// aspecto en toda la app (sin colores a elección de quien lo llama).
class MoaiSnackBar {
  static const double defaultSnackWidth = 440.0;
  static const double defaultBottomMargin = 24.0;
  static const Duration defaultDuration = Duration(seconds: 2);

  /// Construye el widget SnackBar con el diseño estándar tipo pill.
  static SnackBar buildSnackBar({
    required BuildContext? context,
    required String message,
    IconData? icon,
    String? hint,
    VoidCallback? onAction,
    VoidCallback? onBack,
    double bottomMargin = defaultBottomMargin,
    Duration duration = defaultDuration,
    double targetWidth = defaultSnackWidth,
  }) {
    return SnackBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      behavior: SnackBarBehavior.floating,
      clipBehavior: Clip.none,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.fromLTRB(24, 0, 24, bottomMargin),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Align(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: targetWidth),
          child: _MoaiSnackBarBody(
            message: message,
            hint: hint,
            icon: icon ?? MoaiIcons.info,
            onAction: onAction,
            onBack: onBack,
            textContext: context,
          ),
        ),
      ),
      duration: duration,
    );
  }

  /// Muestra un SnackBar genérico estilo pill usando el BuildContext.
  ///
  /// [onDismiss] se llama solo si el usuario lo descarta: atrás con el snack
  /// enfocado, vencimiento o deslizamiento. Que otro snack o un diálogo lo
  /// tape NO cuenta como descarte (SPEC-50 §2.3).
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    String? hint,
    VoidCallback? onAction,
    VoidCallback? onDismiss,
    double bottomMargin = defaultBottomMargin,
    Duration duration = defaultDuration,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    var settled = false;
    final controller = messenger.showSnackBar(
      buildSnackBar(
        context: context,
        message: message,
        icon: icon,
        hint: hint,
        onAction: onAction == null
            ? null
            : () {
                settled = true;
                onAction();
                messenger.hideCurrentSnackBar();
              },
        onBack: onDismiss == null
            ? null
            : () {
                settled = true;
                onDismiss();
                messenger.hideCurrentSnackBar();
              },
        bottomMargin: bottomMargin,
        duration: duration,
      ),
    );
    if (onDismiss != null) {
      controller.closed.then((reason) {
        if (settled) return;
        if (reason == SnackBarClosedReason.timeout ||
            reason == SnackBarClosedReason.swipe ||
            reason == SnackBarClosedReason.dismiss) {
          onDismiss();
        }
      });
    }
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
      icon: MoaiIcons.checkCircle,
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
      icon: MoaiIcons.error,
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
      icon: MoaiIcons.info,
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
      icon: MoaiIcons.warning,
      bottomMargin: bottomMargin,
      duration: duration,
    );
  }
}

class _MoaiSnackBarBody extends StatefulWidget {
  final String message;
  final String? hint;
  final IconData icon;
  final VoidCallback? onAction;
  final VoidCallback? onBack;
  final BuildContext? textContext;

  const _MoaiSnackBarBody({
    required this.message,
    required this.icon,
    this.hint,
    this.onAction,
    this.onBack,
    this.textContext,
  });

  @override
  State<_MoaiSnackBarBody> createState() => _MoaiSnackBarBodyState();
}

class _MoaiSnackBarBodyState extends State<_MoaiSnackBarBody> {
  final FocusNode _focusNode = FocusNode(skipTraversal: true);
  FocusNode? _previouslyFocusedNode;
  bool _tookFocus = false;

  @override
  void initState() {
    super.initState();
    if (widget.onAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Si hay un modal o diálogo activo, nunca robar el foco bajo ninguna circunstancia
        if (ModalRouteTracker.instance.hasActiveModal) return;
        _previouslyFocusedNode = FocusManager.instance.primaryFocus;
        _focusNode.requestFocus();
        _tookFocus = true;
      });
    }
  }

  @override
  void dispose() {
    if (_tookFocus &&
        _previouslyFocusedNode != null &&
        (_previouslyFocusedNode!.context?.mounted ?? false)) {
      _previouslyFocusedNode!.requestFocus();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _runAction() {
    widget.onAction?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textContext = widget.textContext ?? context;
    final actionLabel = widget.hint;

    final hasAction =
        widget.onAction != null &&
        actionLabel != null &&
        actionLabel.isNotEmpty;

    // La base va debajo del cristal porque el snack también sale sobre el
    // video, y sola no se leería. Sombra apenas marcada.
    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000), // negro al 12 %
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: MoaiGlass(
        elevated: false,
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: scheme.primary, size: MoaiIconSizes.lg),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                widget.message,
                textAlign: TextAlign.start,
                style: MoaiText.body(
                  textContext,
                  color: scheme.onSurface,
                  fontSize: 14,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasAction) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _runAction,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      actionLabel,
                      style: MoaiText.body(
                        textContext,
                        color: scheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.onAction == null) {
      return body;
    }

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            TvKeyHandler.isActionKey(event.logicalKey)) {
          _runAction();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent &&
            widget.onBack != null &&
            (event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.escape)) {
          widget.onBack!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: body,
    );
  }
}
