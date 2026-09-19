import 'package:flutter/widgets.dart';

/// Contrato de un área del home (TV, futuro visor…).
///
/// El [HomeScreen] **solo orquesta**:
/// - rail → derecha → [requestEntryFocus] del área activa
/// - área → izquierda → vuelve al rail (vía callback del área)
///
/// Cada área posee sus FocusNodes y su D-pad interno. El shell no conoce
/// paneles, filas ni teclas internas.
///
/// Ajustes hoy no implementa este contrato: sus [FocusNode] viven en el shell
/// (paridad con moaiSmart).
abstract class HomeAreaState<T extends StatefulWidget> extends State<T> {
  /// Punto de entrada de foco al llegar desde el rail (o desde otra área).
  void requestEntryFocus();
}

