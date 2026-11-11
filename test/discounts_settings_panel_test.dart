import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moai3/features/discounts/widgets/discounts_settings_panel.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/services/discounts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/spanish_translations.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DiscountsService.instance.resetForTest(
      client: MockClient((_) async => http.Response('[]', 500)),
      directory: await Directory.systemTemp.createTemp('descuentos_config'),
    );
  });

  for (final height in [700.0, 1000.0]) {
    testWidgets(
      'Configurar: 6 fichas que llenan el alto y título con degradado ($height)',
      (tester) async {
        useSpanishTranslations();
        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final focus = FocusNode();
        addTearDown(focus.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 600,
                  height: height,
                  child: DiscountsSettingsPanel(
                    focusNode: focus,
                    onKeyLeft: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final title = find.text('Configurar');
        expect(
          find.ancestor(of: title, matching: find.byType(ShaderMask)),
          findsOneWidget,
        );

        final actions = find.byType(TvSettingsActionRow);
        final switches = find.byType(TvSettingsSwitchRow);
        // 3 acciones y, en la primera ventana, 3 rubros.
        expect(actions, findsNWidgets(3));
        expect(switches, findsNWidgets(3));

        final firstTop = tester.getTopLeft(actions.first).dy;
        final lastBottom = tester.getBottomLeft(switches.last).dy;
        final titleBottom = tester.getBottomLeft(title).dy;

        // La lista arranca bajo el encabezado (sin hueco) y llega al pie.
        expect(firstTop - titleBottom, lessThan(60));
        expect(height - lastBottom, lessThan(20));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
