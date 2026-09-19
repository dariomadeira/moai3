import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/controllers/viewer_favorites_controller.dart';

void main() {
  test('syncFrom crea y elimina FocusNodes según cantidad', () {
    final controller = ViewerFavoritesController();

    controller.syncFrom(3);
    expect(controller.focusNodes, hasLength(3));

    controller.syncFrom(1);
    expect(controller.focusNodes, hasLength(1));

    controller.syncFrom(0);
    expect(controller.focusNodes, isEmpty);

    controller.dispose();
  });
}

