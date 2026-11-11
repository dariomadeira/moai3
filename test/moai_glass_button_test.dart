import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

void main() {
  test('el botón mide lo mismo con y sin foco (nada se mueve al enfocar)', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    final idle = moaiGlassButtonDecoration(scheme, focused: false);
    final focused = moaiGlassButtonDecoration(scheme, focused: true);
    expect(focused.padding, idle.padding);
  });
}
