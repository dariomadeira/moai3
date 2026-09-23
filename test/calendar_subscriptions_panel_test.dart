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
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 700,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('renders CalendarSubscriptionsPanel with TvSettingsSwitchRows', (tester) async {
    final calendarProvider = CalendarProvider();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      wrap(
        CalendarSubscriptionsPanel(
          focusNode: focusNode,
          onKeyLeft: () {},
        ),
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
    expect(find.text('Fórmula 1'), findsOneWidget);
    expect(find.text('Fútbol Argentino (LPF)'), findsOneWidget);

    // Verify Switches are present
    expect(find.byType(Switch), findsWidgets);

    focusNode.dispose();
  });

  testWidgets('toggles subscription on tap', (tester) async {
    final calendarProvider = CalendarProvider();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      wrap(
        CalendarSubscriptionsPanel(
          focusNode: focusNode,
          onKeyLeft: () {},
        ),
        calendarProvider: calendarProvider,
      ),
    );
    await tester.pump();

    final f1Initial = calendarProvider.subscriptions.firstWhere((s) => s.id == 'f1').isSubscribed;
    expect(f1Initial, isFalse);

    // Tap on the first TvSettingsSwitchRow (F1)
    await tester.tap(find.text('Fórmula 1'));
    await tester.pump();

    final f1After = calendarProvider.subscriptions.firstWhere((s) => s.id == 'f1').isSubscribed;
    expect(f1After, isTrue);

    focusNode.dispose();
  });
}

