import 'package:flutter/widgets.dart';

/// Contrato de un área del home (Inicio, TV, Agenda, Arcade, Ajustes…).
///
/// El [HomeScreen] **solo orquesta**:
/// - rail → derecha → [requestEntryFocus] del área activa
/// - back → [handleBack] del área activa; si no lo consume, sube al rail
/// - área → izquierda → vuelve al rail (vía callback del área)
///
/// Cada área posee sus FocusNodes y su D-pad interno. El shell no conoce
/// paneles, filas ni teclas internas.
abstract class HomeAreaState<T extends StatefulWidget> extends State<T> {
  /// Punto de entrada de foco al llegar desde el rail (o desde otra área).
  void requestEntryFocus();

  /// Back del D-pad. `true` si el área lo consumió (no subir al rail).
  bool handleBack() => false;
}
