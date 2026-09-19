import 'package:flutter/material.dart';

/// Estilo de ítems de lista TV (paridad moaiSmart):
/// foco = borde primary; selección = overlay; sin scale.
@immutable
class TvListCardStyle {
  final Color backgroundColor;
  final Color foregroundColor;
  final Color iconColor;
  final FontWeight fontWeight;
  final Border border;

  const TvListCardStyle({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.iconColor,
    required this.fontWeight,
    required this.border,
  });

  factory TvListCardStyle.resolve({
    required ColorScheme scheme,
    required bool focused,
    required bool selected,
  }) {
    if (focused) {
      return TvListCardStyle(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        iconColor: scheme.onPrimary,
        fontWeight: FontWeight.w700,
        border: Border.all(color: Colors.transparent, width: 2),
      );
    }

    if (selected) {
      return TvListCardStyle(
        backgroundColor: scheme.primaryContainer.withValues(alpha: 0.5),
        foregroundColor: scheme.onPrimaryContainer,
        iconColor: scheme.onPrimaryContainer,
        fontWeight: FontWeight.w700,
        border: Border.all(color: Colors.transparent, width: 2),
      );
    }

    return TvListCardStyle(
      backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.18),
      foregroundColor: scheme.onSurface,
      iconColor: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      border: Border.all(color: Colors.transparent, width: 2),
    );
  }
}

