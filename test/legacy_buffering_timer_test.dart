import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Regresión: el patrón de cancelación del timer legacy evita callbacks tardíos.
void main() {
  test('cancelar timer de buffering evita ejecución posterior', () async {
    var fired = false;
    Timer? timer = Timer(const Duration(milliseconds: 50), () {
      fired = true;
    });

    timer.cancel();
    timer = null;

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fired, isFalse);
  });
}

