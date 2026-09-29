import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/services/modal_route_tracker.dart';
import 'package:moai3/theme/moai_text.dart';

/// Sistema unificado de SnackBar estilo Pill para Moai.
/// Centrado, flotante, colores del rail activo y sombra negra.
class MoaiSnackBar {
  static const double defaultSnackWidth = 440.0;
  static const double defaultBottomMargin = 24.0;
  static const Duration defaultDuration = Duration(seconds: 2);

  /// Construye el widget SnackBar con el diseño estándar tipo pill.
  static SnackBar buildSnackBar({
    required BuildContext? context,
    required String message,
    IconData? icon,
    Color? iconColor,
    Color? backgroundColor,
    String? hint,
    VoidCallback? onAction,
    double bottomMargin = defaultBottomMargin,
    Duration duration = defaultDuration,
    double targetWidth = defaultSnackWidth,
  }) {
    final scheme = context != null ? Theme.of(context).colorScheme : null;
    final fg = scheme?.onPrimary ?? Colors.white;
    final bg = backgroundColor ?? scheme?.primary ?? Colors.black;

    return SnackBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      behavior: SnackBarBehavior.floating,
      clipBehavior: Clip.none,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.fromLTRB(24, 0, 24, bottomMargin),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: targetWidth),
          child: _MoaiSnackBarBody(
            message: message,
            hint: hint,
            icon: icon,
            iconColor: iconColor ?? fg,
            foregroundColor: fg,
            backgroundColor: bg,
            onAction: onAction,
            textContext: context,
          ),
        ),
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
    Color? backgroundColor,
    String? hint,
    VoidCallback? onAction,
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
        hint: hint,
        onAction: onAction,
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
      icon: Icons.warning_amber_outlined,
      bottomMargin: bottomMargin,
      duration: duration,
    );
  }
}

class _MoaiSnackBarBody extends StatefulWidget {
  final String message;
  final String? hint;
  final IconData? icon;
  final Color iconColor;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback? onAction;
  final BuildContext? textContext;

  const _MoaiSnackBarBody({
    required this.message,
    required this.iconColor,
    required this.foregroundColor,
    required this.backgroundColor,
    this.hint,
    this.icon,
    this.onAction,
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
    final fg = widget.foregroundColor;
    final textContext = widget.textContext ?? context;
    final actionLabel = widget.hint;

    final hasAction = widget.onAction != null &&
        actionLabel != null &&
        actionLabel.isNotEmpty;

    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: widget.iconColor, size: 22),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                widget.message,
                textAlign: TextAlign.start,
                style: MoaiText.body(
                  textContext,
                  color: fg,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
                    color: fg,
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
                        color: widget.backgroundColor,
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
        return KeyEventResult.ignored;
      },
      child: body,
    );
  }
}

