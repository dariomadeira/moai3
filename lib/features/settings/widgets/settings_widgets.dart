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

  /// Color propio del ícono (ver [TvTile.iconColor]).
  final Color? iconColor;
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
    this.iconColor,
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
      iconColor: iconColor,
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

  /// Color propio del ícono (ver [TvTile.iconColor]).
  final Color? iconColor;
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
    this.iconColor,
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
      iconColor: iconColor,
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

/// Switch del estilo cristal, uno solo para toda la app. Encendido: pista
/// del acento con brillo arriba y halo del acento. Apagado: el mismo efecto
/// en gris suave. El foco es de la ficha: el switch no cambia con él. Solo
/// lectura: la ficha que lo contiene maneja el cambio.
class _GlassSwitch extends StatelessWidget {
  const _GlassSwitch({required this.value});

  final bool value;

  static const _width = 52.0;
  static const _height = 30.0;
  static const _inset = 3.0;
  static const _thumb = _height - 2 * _inset - 2; // descuenta el borde
  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final dark = scheme.brightness == Brightness.dark;
    // Gris suave del apagado: mismo tratamiento que el acento encendido.
    final grey = dark ? const Color(0xFF8A8F98) : const Color(0xFFB7BCC4);
    final tone = value ? scheme.primary : grey;

    final track = BoxDecoration(
      borderRadius: BorderRadius.circular(_height / 2),
      border: Border.all(
        color: Color.lerp(tone, Colors.black, 0.12)!.withValues(alpha: 0.5),
      ),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(tone, Colors.white, 0.28)!, tone],
      ),
      boxShadow: [
        BoxShadow(
          color: tone.withValues(alpha: value ? 0.32 : 0.22),
          blurRadius: 10,
          spreadRadius: -2,
          offset: const Offset(0, 3),
        ),
      ],
    );

    return AnimatedContainer(
      duration: _duration,
      curve: Curves.easeOutCubic,
      width: _width,
      height: _height,
      padding: const EdgeInsets.all(_inset),
      decoration: track,
      child: AnimatedAlign(
        duration: _duration,
        curve: Curves.easeOutBack,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: _thumb,
          height: _thumb,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
