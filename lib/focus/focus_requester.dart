import 'package:flutter/widgets.dart';

/// Panel que sabe enfocar su ítem seleccionado.
abstract interface class FocusSelectable {
  void focusSelected();
}

/// Pedidos de foco de un área, con reintento frame a frame hasta que el
/// destino exista en el árbol (SPEC-50 §2.10).
///
/// Un pedido nuevo cancela el anterior: un reintento atrasado nunca pisa una
/// navegación más reciente.
class FocusRequester {
  FocusRequester({required this.isMounted});

  final bool Function() isMounted;
  int _epoch = 0;

  /// Descarta cualquier pedido pendiente.
  void cancel() => _epoch++;

  /// Llama a [attempt] en los próximos frames hasta que devuelva `true`, se
  /// agoten [maxFrames], el área se desmonte o llegue un pedido más nuevo.
  /// Con [immediate] intenta primero en el acto, sin esperar un frame.
  void request(
    bool Function() attempt, {
    int maxFrames = 15,
    bool immediate = false,
  }) {
    final epoch = ++_epoch;
    if (immediate && isMounted() && attempt()) return;
    void tick(int left) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (epoch != _epoch || !isMounted()) return;
        if (attempt() || left <= 0) return;
        tick(left - 1);
      });
    }

    tick(maxFrames);
  }

  /// Enfoca [node] cuando tenga contexto.
  void node(FocusNode node, {int maxFrames = 15, bool immediate = false}) =>
      request(() {
        if (node.context == null || !node.canRequestFocus) return false;
        node.requestFocus();
        return immediate || node.hasFocus;
      }, maxFrames: maxFrames, immediate: immediate);

  /// Enfoca el ítem seleccionado del panel de [key] cuando esté montado.
  void selected(
    GlobalKey<State<StatefulWidget>> key, {
    int maxFrames = 15,
  }) =>
      request(() {
        final state = key.currentState;
        if (state is! FocusSelectable) return false;
        (state as FocusSelectable).focusSelected();
        return true;
      }, maxFrames: maxFrames);
}
