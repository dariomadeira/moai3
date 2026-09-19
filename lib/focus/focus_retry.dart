import 'package:flutter/widgets.dart';

/// Reintenta [FocusNode.requestFocus] hasta que el node esté montado.
///
/// Útil al cambiar de panel/área: el destino a veces aún no tiene `context`.
void requestFocusWithRetry(
  FocusNode node, {
  bool Function()? isMounted,
  int attempts = 20,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (isMounted != null && !isMounted()) return;
    if (node.canRequestFocus && node.context != null) {
      node.requestFocus();
      if (node.hasFocus) return;
    }
    if (attempts > 0) {
      requestFocusWithRetry(
        node,
        isMounted: isMounted,
        attempts: attempts - 1,
      );
    }
  });
}

