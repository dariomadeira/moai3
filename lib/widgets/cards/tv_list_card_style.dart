import 'package:flutter/material.dart';

/// Estilo de ítems de lista TV (paridad moaiSmart / ajustes):
/// foco = relleno primary; selección = overlay; sin scale.
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
    // Mismo criterio de borde que [TvTile]: primary con foco,
    // outlineVariant suave en reposo / selección.
    final Border border = Border.all(
      color: focused
          ? scheme.primary
          : scheme.outlineVariant.withValues(alpha: 0.12),
    );

    if (focused) {
      return TvListCardStyle(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        iconColor: scheme.onPrimary,
        fontWeight: FontWeight.w700,
        border: border,
      );
    }

    if (selected) {
      return TvListCardStyle(
        backgroundColor: scheme.primaryContainer.withValues(alpha: 0.5),
        foregroundColor: scheme.onPrimaryContainer,
        iconColor: scheme.onPrimaryContainer,
        fontWeight: FontWeight.w700,
        border: border,
      );
    }

    return TvListCardStyle(
      backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.18),
      foregroundColor: scheme.onSurface,
      iconColor: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      border: border,
    );
  }
}

