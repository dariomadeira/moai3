import 'package:flutter/material.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';

class TvSettingsActionRow extends StatelessWidget {
  final FocusNode focusNode;
  final String label;
  final String description;
  final IconData? icon;
  final VoidCallback onPressed;
  final VoidCallback onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final EdgeInsetsGeometry? padding;
  final double? minHeight;

  const TvSettingsActionRow({
    super.key,
    required this.focusNode,
    required this.label,
    required this.description,
    this.icon,
    required this.onPressed,
    required this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
    this.padding,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return TvTile(
      focusNode: focusNode,
      label: label,
      description: description,
      icon: icon,
      padding: padding,
      minHeight: minHeight,
      onPressed: onPressed,
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
      trailingBuilder: (context, isFocused) {
        final scheme = context.scheme;
        return Icon(
          MoaiIcons.chevronRight,
          size: MoaiIconSizes.lg,
          color: isFocused ? scheme.onPrimary : scheme.onSurfaceVariant,
        );
      },
    );
  }
}

class TvSettingsSwitchRow extends StatelessWidget {
  final FocusNode focusNode;
  final String label;
  final String? description;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final EdgeInsetsGeometry? padding;
  final double? minHeight;

  const TvSettingsSwitchRow({
    super.key,
    required this.focusNode,
    required this.label,
    this.description,
    this.icon,
    required this.value,
    required this.onChanged,
    required this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
    this.padding,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return TvTile(
      focusNode: focusNode,
      label: label,
      description: description,
      icon: icon,
      padding: padding,
      minHeight: minHeight,
      onPressed: () => onChanged(!value),
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
      trailingBuilder: (context, isFocused) {
        if (MoaiGlassScope.enabledOf(context)) {
          return _GlassSwitch(value: value);
        }
        final scheme = context.scheme;

        final trackColor = isFocused
            ? (value
                  ? scheme.onPrimary
                  : scheme.onPrimary.withValues(alpha: 0.3))
            : (value ? scheme.primary : scheme.surfaceContainerHighest);

        final thumbColor = isFocused
            ? (value ? scheme.primary : scheme.onPrimary.withValues(alpha: 0.7))
            : (value ? scheme.onPrimary : scheme.outline);

        final outlineColor = isFocused
            ? (value
                  ? Colors.transparent
                  : scheme.onPrimary.withValues(alpha: 0.5))
            : (value ? Colors.transparent : scheme.outlineVariant);

        return IgnorePointer(
          child: Switch(
            value: value,
            onChanged: (_) {},
            activeTrackColor: trackColor,
            inactiveTrackColor: trackColor,
            activeThumbColor: thumbColor,
            inactiveThumbColor: thumbColor,
            trackOutlineColor: WidgetStateProperty.all(outlineColor),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      },
    );
  }
}

/// Switch del estilo cristal: pista translúcida apagado, del acento con un
/// brillo leve encendido; con foco y apagado, la pista toma el borde del
/// acento. Solo lectura: la ficha que lo contiene maneja el cambio.
class _GlassSwitch extends StatelessWidget {
  const _GlassSwitch({required this.value});

  final bool value;

  static const _width = 46.0;
  static const _height = 26.0;
  static const _thumb = 20.0;
  static const _duration = Duration(milliseconds: 160);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final dark = scheme.brightness == Brightness.dark;
    final focused = TvTile.isFocusedOf(context);

    final offFill = (dark ? Colors.white : scheme.onSurface).withValues(
      alpha: dark ? 0.06 : 0.08,
    );
    final rim = value
        ? Colors.transparent
        : (focused
              ? scheme.primary
              : (dark ? Colors.white : scheme.onSurface).withValues(
                  alpha: 0.14,
                ));

    return AnimatedContainer(
      duration: _duration,
      curve: Curves.easeOutCubic,
      width: _width,
      height: _height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_height / 2),
        border: Border.all(color: rim),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: value
              ? [
                  Color.lerp(scheme.primary, Colors.white, 0.15)!,
                  scheme.primary,
                ]
              : [offFill, offFill],
        ),
      ),
      child: AnimatedAlign(
        duration: _duration,
        curve: Curves.easeOutCubic,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: _duration,
          width: _thumb - 2,
          height: _thumb - 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value
                ? scheme.onPrimary
                : scheme.onSurfaceVariant.withValues(
                    alpha: focused ? 0.9 : 0.6,
                  ),
          ),
        ),
      ),
    );
  }
}
