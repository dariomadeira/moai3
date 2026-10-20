import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/tv_bottom_weather_pill.dart';
import 'package:moai3/features/home/widgets/tv_vertical_nav_rail.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:provider/provider.dart';

Widget _wrap(Widget child, {CalendarProvider? calendarProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CalendarProvider>.value(
        value: calendarProvider ?? CalendarProvider(startTicker: false),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TvVerticalNavRail', () {
    testWidgets(
        'muestra iconos Reicon en destinos circulares sin label vertical',
        (tester) async {
      final scopeNode = FocusScopeNode();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _wrap(
          TvVerticalNavRail(
            selectedIndex: 0,
            railScopeNode: scopeNode,
            railFocusNode: focusNode,
            onIndexChanged: (_) {},
            onFocusRight: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(MoaiIcons.railHomeSelected), findsOneWidget);
      expect(find.byIcon(MoaiIcons.railTv), findsOneWidget);
      expect(find.byIcon(MoaiIcons.railFeatured), findsOneWidget);
      expect(find.byIcon(MoaiIcons.railMovies), findsOneWidget);
      expect(find.byIcon(MoaiIcons.railSeries), findsOneWidget);
      expect(find.byIcon(MoaiIcons.railCalendar), findsOneWidget);
      expect(find.byIcon(MoaiIcons.railSettings), findsOneWidget);
      expect(find.byIcon(MoaiIcons.railArcade), findsNothing);
      expect(find.byIcon(MoaiIcons.railArcadeSelected), findsNothing);

      // Ya no muestra texto vertical
      expect(find.text('home_rail_home_title'), findsNothing);
      expect(find.text('home_rail_tv_title'), findsNothing);
      expect(find.text('home_rail_featured_title'), findsNothing);
      expect(find.text('home_rail_movies_title'), findsNothing);
      expect(find.text('home_rail_series_title'), findsNothing);
      expect(find.text('home_rail_calendar_title'), findsNothing);
      expect(find.text('home_rail_settings_title'), findsNothing);

      scopeNode.dispose();
      focusNode.dispose();
    });

    testWidgets('renderiza TvBottomWeatherPill en la parte superior (top: 8)',
        (tester) async {
      final scopeNode = FocusScopeNode();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _wrap(
          TvVerticalNavRail(
            selectedIndex: 0,
            railScopeNode: scopeNode,
            railFocusNode: focusNode,
            onIndexChanged: (_) {},
            onFocusRight: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final positionedFinder = find.ancestor(
        of: find.byType(TvBottomWeatherPill),
        matching: find.byType(Positioned),
      );
      expect(positionedFinder, findsOneWidget);

      final positionedWidget = tester.widget<Positioned>(positionedFinder);
      expect(positionedWidget.top, 8.0);
      expect(positionedWidget.bottom, isNull);

      scopeNode.dispose();
      focusNode.dispose();
    });

    testWidgets(
        'D-pad sin Arcade recorre Inicio -> TV -> Destacados -> Películas -> Series -> Agenda -> Ajustes',
        (tester) async {
      var selected = 0;
      final scopeNode = FocusScopeNode();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return TvVerticalNavRail(
                selectedIndex: selected,
                railScopeNode: scopeNode,
                railFocusNode: focusNode,
                onIndexChanged: (i) => setState(() => selected = i),
                onFocusRight: () {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      // Inicio (0) -> TV (1)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(selected, 1);

      // TV -> Destacados (2)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(selected, 2);

      // Destacados -> Películas (3)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(selected, 3);

      // Películas -> Series (4)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(selected, 4);

      // Series -> Agenda (5)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(selected, 5);

      // Agenda -> Ajustes (7)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(selected, 7);

      scopeNode.dispose();
      focusNode.dispose();
    });
  });
}
