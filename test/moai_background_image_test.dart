import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/widgets/tv_common/moai_background_image.dart';

void main() {
  group('MoaiBackgroundImage.decodeWidth', () {
    test('tele 1080p (960×540 lógicos, x2): fondo 4K se carga a 1920', () {
      expect(
        MoaiBackgroundImage.decodeWidth(
          MoaiBackground.screen,
          const Size(960, 540),
          2,
        ),
        1920,
      );
    });

    test('interfaz en 4K: usa el archivo completo, nunca más grande', () {
      expect(
        MoaiBackgroundImage.decodeWidth(
          MoaiBackground.screen,
          const Size(1920, 1080),
          2,
        ),
        3840,
      );
      expect(
        MoaiBackgroundImage.decodeWidth(
          MoaiBackground.screen,
          const Size(3840, 2160),
          2,
        ),
        3840,
      );
    });

    test('diálogo: cubre el lado que más se estira, en escalones de 128', () {
      // 520×300 lógicos x2: el ancho manda (1040 → 1152).
      expect(
        MoaiBackgroundImage.decodeWidth(
          MoaiBackground.dialog,
          const Size(520, 300),
          2,
        ),
        1152,
      );
      // 300×600 lógicos x2: el alto manda (1200 × 2100/2160 ≈ 1167 → 1280).
      expect(
        MoaiBackgroundImage.decodeWidth(
          MoaiBackground.dialog,
          const Size(300, 600),
          2,
        ),
        1280,
      );
    });
  });

  testWidgets('pide la imagen al tamaño en pantalla', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: MoaiBackgroundImage(MoaiBackground.screen),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).width, 1920);
  });
}
