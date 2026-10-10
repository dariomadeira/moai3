import 'package:flutter/material.dart';
import 'package:moai3/features/settings/widgets/tv_tile.dart';
import 'package:moai3/theme/moai_text.dart';

class TvSettingsActionRow extends StatelessWidget {
  final FocusNode focusNode;
  final String label;
  final String description;
  final dynamic icon;
  final Color? iconAccentColor;
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
    this.iconAccentColor,
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
      iconAccentColor: iconAccentColor,
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
          Icons.chevron_right,
          size: 26,
          color: isFocused ? scheme.primary : scheme.onSurfaceVariant,
        );
      },
    );
  }
}

class TvSettingsSwitchRow extends StatelessWidget {
  final FocusNode focusNode;
  final String label;
  final String? description;
  final dynamic icon;
  final Color? iconAccentColor;
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
    this.iconAccentColor,
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
      iconAccentColor: iconAccentColor,
      padding: padding,
      minHeight: minHeight,
      onPressed: () => onChanged(!value),
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
      trailingBuilder: (context, isFocused) {
        final scheme = context.scheme;

        final trackColor = value
            ? scheme.primary
            : (isFocused
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainerHighest);

        final thumbColor = value
            ? scheme.onPrimary
            : (isFocused ? scheme.primary : scheme.outline);

        final outlineColor = isFocused
            ? scheme.primary
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
            trackOutlineWidth: WidgetStateProperty.all(isFocused ? 1.5 : 1.0),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      },
    );
  }
}


