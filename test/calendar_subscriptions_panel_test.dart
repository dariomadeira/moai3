import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/calendar/widgets/calendar_subscriptions_panel.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/models/sport_subscription.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child, {required CalendarProvider calendarProvider}) {
    return ChangeNotifierProvider<CalendarProvider>.value(
      value: calendarProvider,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: SizedBox(width: 500, height: 700, child: child)),
      ),
    );
  }

  testWidgets('renders CalendarSubscriptionsPanel with TvSettingsSwitchRows', (
    tester,
  ) async {
    final calendarProvider = CalendarProvider();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      wrap(
        CalendarSubscriptionsPanel(focusNode: focusNode, onKeyLeft: () {}),
        calendarProvider: calendarProvider,
      ),
    );
    await tester.pump();

    // Verify Title is displayed
    expect(find.text('calendar_panel_subscriptions_title'), findsOneWidget);

    // Verify TvWindowedList is used
    expect(find.byType(TvWindowedList<SportSubscription>), findsOneWidget);

    // Verify TvSettingsSwitchRow instances are rendered for default subscriptions
    expect(find.byType(TvSettingsSwitchRow), findsWidgets);
    expect(find.text('calendar_sub_f1_name'), findsOneWidget);
    expect(find.text('calendar_sub_lpf_name'), findsOneWidget);

    focusNode.dispose();
  });

  testWidgets('toggles subscription on tap', (tester) async {
    final calendarProvider = CalendarProvider();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      wrap(
        CalendarSubscriptionsPanel(focusNode: focusNode, onKeyLeft: () {}),
        calendarProvider: calendarProvider,
      ),
    );
    await tester.pump();

    final f1Initial = calendarProvider.subscriptions
        .firstWhere((s) => s.id == 'f1')
        .isSubscribed;
    expect(f1Initial, isFalse);

    // Tap on the first TvSettingsSwitchRow (F1)
    await tester.tap(find.text('calendar_sub_f1_name'));
    await tester.pump();

    final f1After = calendarProvider.subscriptions
        .firstWhere((s) => s.id == 'f1')
        .isSubscribed;
    expect(f1After, isTrue);

    focusNode.dispose();
  });
  for (final height in [700.0, 1000.0]) {
    testWidgets(
      'los 6 ítems llenan el alto sin hueco bajo el título ($height)',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final calendarProvider = CalendarProvider();
        final focusNode = FocusNode();

        await tester.pumpWidget(
          ChangeNotifierProvider<CalendarProvider>.value(
            value: calendarProvider,
            child: MaterialApp(
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 500,
                    height: height,
                    child: CalendarSubscriptionsPanel(
                      focusNode: focusNode,
                      onKeyLeft: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // El título lleva el degradado.
        expect(
          find.ancestor(
            of: find.text('calendar_panel_subscriptions_title'),
            matching: find.byType(ShaderMask),
          ),
          findsOneWidget,
        );

        final subtitleBottom = tester
            .getBottomLeft(find.text('calendar_subscriptions_desc'))
            .dy;
        final rows = find.byType(TvSettingsSwitchRow);
        expect(rows, findsNWidgets(6));
        final firstTop = tester.getTopLeft(rows.first).dy;
        final lastBottom = tester.getBottomLeft(rows.last).dy;

        // Mismo espacio entre el subtítulo y la lista en cualquier alto, y la
        // última ficha llega al pie del panel.
        expect(firstTop - subtitleBottom, lessThan(30));
        expect(height - lastBottom, lessThan(20));

        focusNode.dispose();
      },
    );
  }
}
