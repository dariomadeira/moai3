import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Al abrir una pantalla, deja el foco en [target] hasta la primera tecla.
///
/// En el TV la pantalla no deja enfocar nada adentro hasta terminar de
/// abrirse, y después le da el foco a su grupo o a lo primero que encuentra
/// (en los detalles quedaba en Atrás y la primera tecla se iba ahí). Hasta
/// que la persona aprieta una tecla, cualquier foco que no sea [target]
/// vuelve a él; desde ahí el foco es suyo. La tecla que suelta el OK que
/// abrió la pantalla no cuenta (sólo las apretadas).
class OpeningFocusGuard {
  OpeningFocusGuard({required this.target, required this.isActive});

  final FocusNode target;

  /// La pantalla sigue montada y adelante (no tapada por otra).
  final bool Function() isActive;

  bool _done = false;
  int _retries = 0;

  /// Tope de reintentos seguidos, por si algo lo impide de verdad.
  static const int maxRetries = 240;

  void start() {
    FocusManager.instance.addListener(_guard);
    HardwareKeyboard.instance.addHandler(_onKey);
    _guard();
  }

  void stop() {
    if (_done) return;
    _done = true;
    FocusManager.instance.removeListener(_guard);
    HardwareKeyboard.instance.removeHandler(_onKey);
  }

  void _guard() {
    if (_done) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_done || !isActive() || target.hasFocus) return;
      target.requestFocus();
      // Mientras se abre no deja: se reintenta en el cuadro siguiente.
      if (_retries++ < maxRetries) {
        _guard();
        WidgetsBinding.instance.scheduleFrame();
      }
    });
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent && isActive()) stop();
    return false;
  }
}
