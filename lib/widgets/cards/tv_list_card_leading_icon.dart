import 'package:flutter/material.dart';

/// Leading idéntico a [SettingsActionRow] / [TvTile]:
/// `Material` + `Padding(10)` + `Icon(22)` → cuadrado ~42, no pastilla.
class TvListCardLeadingIcon extends StatelessWidget {
  final IconData icon;
  final bool isFocused;

  /// Compacto para filas de lista (itemExtent 56). False = paridad Settings.
  final bool compact;

  const TvListCardLeadingIcon({
    super.key,
    required this.icon,
    this.isFocused = false,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconBg = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.18)
        : scheme.primaryContainer;
    final iconColor = isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;

    // Settings: padding 10 + icon 22. Compact: 6 + 18 para caber en itemExtent 56.
    final pad = compact ? 8.0 : 10.0;
    final iconSize = compact ? 20.0 : 22.0;
    final radius = compact ? 8.0 : 10.0;

    final side = (pad * 2) + iconSize;

    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: iconSize,
        color: iconColor,
      ),
    );
  }
}

