import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/areas/home_dashboard_area.dart';
import 'package:moai3/theme/moai_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeDashboardArea', () {
    testWidgets('renderiza panel único Inicio a ancho completo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1920,
              height: 1080,
              child: HomeDashboardArea(
                onExitLeft: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Debe mostrar el icono del panel y el título Inicio
      expect(find.byIcon(MoaiIcons.tvAccordionHome), findsOneWidget);
      expect(find.text('home_panel_home_title'), findsWidgets);
    });
  });
}
