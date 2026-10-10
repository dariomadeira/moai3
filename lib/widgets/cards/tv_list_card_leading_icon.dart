import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Leading idéntico a [SettingsActionRow] / [TvTile]:
/// `Material` + `Padding(10)` + `Icon(22)` → cuadrado ~42, no pastilla.
class TvListCardLeadingIcon extends StatelessWidget {
  final IconData? icon;
  final List<List<dynamic>>? hugeIcon;
  final bool isFocused;

  /// Compacto para filas de lista (itemExtent 56). False = paridad Settings.
  final bool compact;

  const TvListCardLeadingIcon({
    super.key,
    this.icon,
    this.hugeIcon,
    this.isFocused = false,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focusedIconColor =
        Color.lerp(scheme.onPrimary, scheme.onPrimaryContainer, 0.38) ??
            scheme.onPrimary;
    final iconColor = isFocused ? focusedIconColor : scheme.onPrimaryContainer;

    final pad = compact ? 8.0 : 10.0;
    final iconSize = compact ? 20.0 : 22.0;
    final radius = compact ? 8.0 : 10.0;

    final side = (pad * 2) + iconSize;

    final Widget childWidget = hugeIcon != null
        ? HugeIcon(
            icon: hugeIcon!,
            size: iconSize,
            color: iconColor,
          )
        : Icon(
            icon ?? Icons.tv_outlined,
            size: iconSize,
            color: iconColor,
          );

    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: childWidget,
    );
  }
}
