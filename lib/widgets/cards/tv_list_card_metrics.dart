/// Métricas compartidas para cards de listas TV (país, categoría, canal).
abstract final class TvListCardMetrics {
  /// Placa apaisada ~3:2 para logos (misma altura ~36 que el leading de ícono).
  static ({
    double logoWidth,
    double logoHeight,
    double gap,
    double fontSize,
  }) forWidth(double maxWidth) {
    final gap = maxWidth < 120 ? 8.0 : 12.0;
    final logoHeight = maxWidth < 120 ? 30.0 : 36.0;
    final logoWidth = (logoHeight * 1.5).clamp(
      0.0,
      (maxWidth - gap - 1).clamp(0.0, 56.0),
    );
    final fontSize = maxWidth < 120 ? 13.0 : 15.0;
    return (
      logoWidth: logoWidth,
      logoHeight: logoHeight,
      gap: gap,
      fontSize: fontSize,
    );
  }

  /// Gap / tipografía para filas con leading de ícono (país / categoría / grupo).
  static ({
    double gap,
    double fontSize,
  }) forIconWidth(double maxWidth) {
    final gap = maxWidth < 120 ? 8.0 : 12.0;
    final fontSize = maxWidth < 120 ? 13.0 : 15.0;
    return (gap: gap, fontSize: fontSize);
  }
}

