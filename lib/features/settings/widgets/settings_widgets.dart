import 'package:flutter/material.dart';
import 'package:moai3/features/settings/widgets/tv_tile.dart';
import 'package:moai3/theme/moai_text.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    return TvTile(
      focusNode: focusNode,
      label: label,
      description: description,
      icon: icon,
      onPressed: onPressed,
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
      trailingBuilder: (context, isFocused) {
        final scheme = context.scheme;
        return Icon(
          Icons.chevron_right_rounded,
          size: 26,
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
  });

  @override
  Widget build(BuildContext context) {
    return TvTile(
      focusNode: focusNode,
      label: label,
      description: description,
      icon: icon,
      onPressed: () => onChanged(!value),
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
      trailingBuilder: (context, isFocused) {
        final scheme = context.scheme;

        final trackColor = isFocused
            ? (value
                ? scheme.onPrimary
                : scheme.onPrimary.withValues(alpha: 0.3))
            : (value
                ? scheme.primary
                : scheme.surfaceContainerHighest);

        final thumbColor = isFocused
            ? (value
                ? scheme.primary
                : scheme.onPrimary.withValues(alpha: 0.7))
            : (value
                ? scheme.onPrimary
                : scheme.outline);

        final outlineColor = isFocused
            ? (value
                ? Colors.transparent
                : scheme.onPrimary.withValues(alpha: 0.5))
            : (value
                ? Colors.transparent
                : scheme.outlineVariant);

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


