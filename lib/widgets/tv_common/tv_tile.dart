import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Misma ficha que [TvTile]: diseño idéntico, puede usarse para tiles de solo lectura
/// o tiles compuestos que gestionan sus propios focos internos (ej. botones de acción).
class TvInfoTile extends StatelessWidget {
  final String label;
  final String? description;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final double? minHeight;
  final bool isFocused;

  const TvInfoTile({
    super.key,
    required this.label,
    this.description,
    this.icon,
    this.trailing,
    this.padding,
    this.minHeight,
    this.isFocused = false,
  });

  @override
  Widget build(BuildContext context) {
    return _TvTileChrome(
      isFocused: isFocused,
      label: label,
      description: description,
      icon: icon,
      trailing: trailing,
      padding: padding,
      minHeight: minHeight,
    );
  }
}

/// Tile base enfocable y reutilizable para ítems TV (Ajustes, Menús, Formulario).
class TvTile extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final String? description;
  final IconData? icon;
  final Widget Function(BuildContext context, bool isFocused)? trailingBuilder;
  final VoidCallback? onPressed;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final FocusOnKeyEventCallback? onKeyEvent;
  final EdgeInsetsGeometry? padding;
  final double? minHeight;

  const TvTile({
    super.key,
    required this.focusNode,
    required this.label,
    this.description,
    this.icon,
    this.trailingBuilder,
    this.onPressed,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
    this.onKeyEvent,
    this.padding,
    this.minHeight,
  });

  @override
  State<TvTile> createState() => _TvTileState();

  /// Si la ficha que contiene a [context] tiene el foco. Sirve a los
  /// elementos de la derecha (p. ej. un switch) en el estilo cristal, donde
  /// el `trailingBuilder` recibe `isFocused: false` para no cambiar de color.
  static bool isFocusedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TvTileFocus>()?.isFocused ??
      false;
}

class _TvTileState extends State<TvTile> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant TvTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode.hasFocus;
    }
  }

  void _runPressed() {
    widget.focusNode.requestFocus();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _isFocused || widget.focusNode.hasFocus;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (widget.onKeyEvent != null) {
          final result = widget.onKeyEvent!(node, event);
          if (result != KeyEventResult.ignored) return result;
        }

        final key = event.logicalKey;

        if (TvKeyHandler.isActionKey(key)) {
          if (event is KeyDownEvent) {
            _runPressed();
            return KeyEventResult.handled;
          }
          if (event is KeyRepeatEvent) return KeyEventResult.handled;
          return KeyEventResult.ignored;
        }

        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        return TvKeyHandler.handleDirectional(
          key: key,
          onLeft: widget.onKeyLeft,
          onRight: widget.onKeyRight,
          onUp: widget.onKeyUp,
          onDown: widget.onKeyDown,
        );
      },
      child: GestureDetector(
        onTap: _runPressed,
        child: _TvTileFocus(
          isFocused: isFocused,
          child: _TvTileChrome(
            isFocused: isFocused,
            label: widget.label,
            description: widget.description,
            icon: widget.icon,
            padding: widget.padding,
            minHeight: widget.minHeight,
            // En cristal el foco no rellena la ficha, así que el trailing
            // conserva sus colores normales.
            trailing: widget.trailingBuilder?.call(
              context,
              isFocused && !MoaiGlassScope.enabledOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _TvTileChrome extends StatelessWidget {
  final bool isFocused;
  final String label;
  final String? description;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final double? minHeight;

  const _TvTileChrome({
    required this.isFocused,
    required this.label,
    this.description,
    this.icon,
    this.trailing,
    this.padding,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // Sobre el fondo ambiente la ficha es de cristal; fuera (diálogos,
    // pantallas con imagen de fondo) mantiene el estilo opaco.
    final glass = MoaiGlassScope.enabledOf(context);
    // En cristal el foco no rellena la ficha: los colores no cambian.
    final solidFocus = isFocused && !glass;
    final bg = isFocused ? scheme.primary : scheme.surfaceContainerLow;
    final titleColor = solidFocus ? scheme.onPrimary : scheme.onSurface;
    final descColor = solidFocus
        ? scheme.onPrimary.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    final iconBg = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.18)
        : scheme.primaryContainer;
    // En cristal el ícono va suelto (como en el rail): acento suave, y pleno
    // con foco para acompañar el borde.
    final iconColor = glass
        ? scheme.primary.withValues(alpha: isFocused ? 1 : 0.75)
        : (solidFocus ? scheme.onPrimary : scheme.onPrimaryContainer);

    final borderColor = isFocused
        ? scheme.primary
        : scheme.outlineVariant.withValues(alpha: 0.12);

    final iconGlyph = Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(icon, size: MoaiIconSizes.lg, color: iconColor),
    );

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final maxTrailingWidth = (constraints.maxWidth - 100).clamp(
          40.0,
          double.infinity,
        );

        return Row(
          children: [
            if (icon != null) ...[
              // Sin fondo ocupa el mismo lugar, así los títulos siguen
              // alineados.
              if (glass)
                iconGlyph
              else
                Material(
                  color: iconBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: iconGlyph,
                ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MoaiText.body(
                      context,
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MoaiText.body(
                        context,
                        color: descColor,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxTrailingWidth),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: trailing,
                ),
              ),
            ],
          ],
        );
      },
    );

    final constraints = BoxConstraints(minHeight: minHeight ?? 58);
    final innerPadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10);

    if (glass) {
      // Cristal discreto; el foco es el mismo de los widgets del Inicio
      // (borde del acento y tinte suave).
      return MoaiGlass(
        borderRadius: 16,
        elevated: false,
        solid: true,
        focused: isFocused,
        padding: innerPadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.minHeight - innerPadding.vertical).clamp(
              0.0,
              double.infinity,
            ),
          ),
          child: content,
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      constraints: constraints,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: innerPadding,
      child: content,
    );
  }
}

/// Expone el foco de la ficha a su contenido ([TvTile.isFocusedOf]).
class _TvTileFocus extends InheritedWidget {
  const _TvTileFocus({required this.isFocused, required super.child});

  final bool isFocused;

  @override
  bool updateShouldNotify(_TvTileFocus oldWidget) =>
      oldWidget.isFocused != isFocused;
}
