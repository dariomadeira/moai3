import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/navigation_rail_section.dart';
import 'package:moai3/state/calendar_provider.dart';
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

  group('NavigationRailSection Tests', () {
    testWidgets('renders TV and Calendar at top, and Settings at bottom', (tester) async {
      int selected = 0;
      final scopeNode = FocusScopeNode();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _wrap(
          NavigationRailSection(
            selectedIndex: selected,
            railScopeNode: scopeNode,
            railFocusNode: focusNode,
            onIndexChanged: (i) => selected = i,
            onFocusRight: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top items
      expect(find.text('home_rail_tv_title'), findsOneWidget);
      expect(find.text('home_rail_calendar_title'), findsOneWidget);
      // Bottom item
      expect(find.text('home_rail_settings_title'), findsOneWidget);

      // Verify positions: TV Y < Calendar Y < Settings Y
      final tvY = tester.getTopLeft(find.text('home_rail_tv_title')).dy;
      final calY = tester.getTopLeft(find.text('home_rail_calendar_title')).dy;
      final setY = tester.getTopLeft(find.text('home_rail_settings_title')).dy;

      expect(tvY < calY, isTrue);
      expect(calY < setY, isTrue);
      // Settings should be near bottom of 600px screen
      expect(setY > 500, isTrue);

      scopeNode.dispose();
      focusNode.dispose();
    });

    testWidgets('displays filled icon when selected and outlined when unselected', (tester) async {
      final scopeNode = FocusScopeNode();
      final focusNode = FocusNode();

      // Selected: TV (0)
      await tester.pumpWidget(
        _wrap(
          NavigationRailSection(
            selectedIndex: 0,
            railScopeNode: scopeNode,
            railFocusNode: focusNode,
            onIndexChanged: (_) {},
            onFocusRight: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // TV is selected: filled Icons.tv
      expect(find.byIcon(Icons.tv), findsOneWidget);
      expect(find.byIcon(Icons.tv_outlined), findsNothing);

      // Calendar is unselected: outlined Icons.calendar_month_outlined
      expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month), findsNothing);

      // Settings is unselected: outlined Icons.settings_outlined
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsNothing);

      scopeNode.dispose();
      focusNode.dispose();
    });

    testWidgets('D-Pad down navigates TV -> Calendario -> Ajustes seamlessly', (tester) async {
      int selected = 0;
      final scopeNode = FocusScopeNode();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) {
              return NavigationRailSection(
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

      // Press Down: 0 -> 1 (Calendario)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Press Down again: 1 -> 2 (Ajustes at the bottom)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Press Action/Enter to select Ajustes
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(selected, equals(3));

      // Press Up: 3 -> 1 (Calendario)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      // Press Up: 1 -> 0 (TV)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();

      expect(selected, equals(0));

      scopeNode.dispose();
      focusNode.dispose();
    });
  });
}
