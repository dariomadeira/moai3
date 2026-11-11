import 'package:flutter/material.dart';

/// Medida común de las fichas de los paneles de lista (Suscripciones,
/// Arcade): 6 lugares que se reparten todo el alto bajo el encabezado, así
/// el espacio entre el título y la primera ficha es el mismo en cualquier
/// pantalla (con un alto fijo, en pantallas más altas sobraba un hueco).
abstract final class TvPanelSlots {
  TvPanelSlots._();

  static const int count = 6;

  /// Alto mínimo de cada lugar (ficha de 62, la que entra con título y
  /// descripción, + [gap]).
  static const double minExtent = 70.0;

  /// Separación entre fichas (la mitad arriba y la mitad abajo de cada una).
  static const double gap = 8.0;

  /// Separación entre el encabezado y la primera ficha.
  static const double headerGap = 14.0;

  /// Lo que va entre el encabezado y la lista: [headerGap] menos la media
  /// separación que la primera ficha ya trae arriba.
  static const Widget belowHeader = SizedBox(height: headerGap - gap / 2);

  /// Padding del contenido del panel (alineado con el de Eventos).
  static const EdgeInsets panelPadding = EdgeInsets.only(
    left: 4,
    right: 12,
    top: 8,
    bottom: 8,
  );

  /// Alto de cada lugar para el alto disponible [maxHeight].
  static double extentFor(double maxHeight) =>
      (maxHeight / count).clamp(minExtent, double.infinity);

  /// Una ficha en su lugar: alto [extent] con media [gap] arriba y abajo.
  static Widget slot({required double extent, required Widget child}) =>
      SizedBox(
        height: extent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: gap / 2),
          child: child,
        ),
      );
}
