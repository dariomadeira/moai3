import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/theme/moai_text.dart';

/// Variante semántica para los botones de acción en modales de Android TV.
enum TvDialogButtonVariant {
  /// Acción principal destacada (ej. Actualizar, Crear, Guardar).
  primary,

  /// Acción neutra o de descarte (ej. Cancelar, Más tarde, Cerrar).
  neutral,

  /// Acción destructiva e irreversible (ej. Vaciar, Eliminar).
  destructive,
}

/// Diálogo base reutilizable para Android TV (Material 3 Expressive).
///
/// Proporciona elevación con sombra ambiental suave, contorno hairline sutil
/// para televisores de alto contraste, caja de icono estandarizada (44x44 dp)
/// y distribución accesible para control remoto D-Pad.
class TvDialog extends StatelessWidget {
  final double width;
  final IconData? icon;
  final Widget? iconWidget;
  final Color? iconBgColor;
  final Color? iconColor;
  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailingHeader;
  final Widget? content;
  final List<Widget>? actions;
  final MainAxisAlignment actionsAlignment;

  final EdgeInsetsGeometry padding;

  const TvDialog({
    super.key,
    this.width = 480,
    this.padding = const EdgeInsets.all(16),
    this.icon,
    this.iconWidget,
    this.iconBgColor,
    this.iconColor,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.subtitleWidget,
    this.trailingHeader,
    this.content,
    this.actions,
    this.actionsAlignment = MainAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Usamos scheme.surface igual que los paneles de TvAccordionRowPreview
    // para lograr el fondo oscuro característico y contraste perfecto con los TvTile
    final baseColor = scheme.surface;
    final endColor = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.05),
      baseColor,
    );
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.48);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomRight,
              end: Alignment.topLeft,
              colors: [baseColor, baseColor, endColor],
              stops: const [0.0, 0.62, 1.0],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 36,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.18,
                    child: Image.asset(
                      'assets/images/fondo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado estandarizado
                    if (icon != null ||
                        iconWidget != null ||
                        title != null ||
                        titleWidget != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (iconWidget != null)
                      iconWidget!
                    else if (icon != null)
                      Icon(
                        icon,
                        color: iconColor ?? scheme.primary,
                        size: 30,
                      ),
                    if (icon != null || iconWidget != null)
                      const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (titleWidget != null)
                            titleWidget!
                          else if (title != null)
                            Text(
                              title!,
                              style: MoaiText.display(
                                context,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                          if (subtitleWidget != null) ...[
                            const SizedBox(height: 2),
                            subtitleWidget!,
                          ] else if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: MoaiText.body(
                                context,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurface.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailingHeader != null) ...[
                      const SizedBox(width: 12),
                      trailingHeader!,
                    ],
                  ],
                ),
                if (content != null || actions != null)
                  const SizedBox(height: 16),
              ],

              // Contenido
              ?content,

              // Botones de acción
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: actionsAlignment,
                  children: [
                    for (int i = 0; i < actions!.length; i++) ...[
                      if (i > 0 && actions![i] is! SizedBox && actions![i - 1] is! SizedBox)
                        const SizedBox(width: 12),
                      actions![i],
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  ),
),
);
  }
}

/// Botón estandarizado para modales de Android TV.
///
/// Colores sólidos basados en tokens M3, esquinas de 12 dp sin bordes compitiendo,
/// y respuesta inmediata al control remoto (Enter / Select / Space y flechas).
class TvDialogButton extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final VoidCallback onPressed;
  final TvDialogButtonVariant variant;
  final IconData? icon;
  final bool autofocus;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const TvDialogButton({
    super.key,
    required this.focusNode,
    required this.label,
    required this.onPressed,
    this.variant = TvDialogButtonVariant.neutral,
    this.icon,
    this.autofocus = false,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  @override
  State<TvDialogButton> createState() => _TvDialogButtonState();
}

class _TvDialogButtonState extends State<TvDialogButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant TvDialogButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color bgColor;
    final Color fgColor;

    if (_isFocused) {
      if (widget.variant == TvDialogButtonVariant.destructive) {
        bgColor = scheme.error;
        fgColor = scheme.onError;
      } else {
        bgColor = scheme.primary;
        fgColor = scheme.onPrimary;
      }
    } else {
      switch (widget.variant) {
        case TvDialogButtonVariant.primary:
          bgColor = scheme.primaryContainer;
          fgColor = scheme.onPrimaryContainer;
        case TvDialogButtonVariant.neutral:
          bgColor = scheme.surfaceContainerHighest;
          fgColor = scheme.onSurfaceVariant;
        case TvDialogButtonVariant.destructive:
          bgColor = scheme.errorContainer;
          fgColor = scheme.onErrorContainer;
      }
    }

    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;

        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.gameButtonA) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft && widget.onKeyLeft != null) {
          widget.onKeyLeft!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight && widget.onKeyRight != null) {
          widget.onKeyRight!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp && widget.onKeyUp != null) {
          widget.onKeyUp!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && widget.onKeyDown != null) {
          widget.onKeyDown!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: fgColor),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: MoaiText.body(
                  context,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper para abrir cualquier diálogo TV con transición fluida de escala y fade.
Future<T?> showTvGeneralDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
  String barrierLabel = 'Cerrar',
  Color? barrierColor,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, anim, secAnim) => builder(ctx),
    transitionBuilder: (ctx, anim, secAnim, child) {
      final curved =
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
