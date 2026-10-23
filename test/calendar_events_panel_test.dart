import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/calendar/widgets/calendar_events_panel.dart';
import 'package:moai3/features/home/areas/home_calendar_area.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/services/calendar/argentina_time.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Miércoles 21 Oct 2026, 12:00 ART: semana Lun 19 – Dom 25.
    ArgentinaTime.debugUtcNow = () => DateTime.utc(2026, 10, 21, 15);
  });

  tearDown(() => ArgentinaTime.debugUtcNow = null);

  CalendarEvent event(String id, String sub, String title, int day, int hour) =>
      CalendarEvent(
        id: id,
        subscriptionId: sub,
        title: title,
        competition: sub,
        startDateTime: ArgentinaTime.fromCivil(2026, 10, day, hour),
      );

  Widget wrap(Widget child, {required CalendarProvider calendarProvider}) {
    return ChangeNotifierProvider<CalendarProvider>.value(
      value: calendarProvider,
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 720,
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets('renders CalendarEventsPanel with 7 days of the week', (tester) async {
    final calendarProvider = CalendarProvider();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      wrap(
        CalendarEventsPanel(
          focusNode: focusNode,
          onKeyLeft: () {},
          onKeyRight: () {},
        ),
        calendarProvider: calendarProvider,
      ),
    );
    await tester.pump();

    // Verify all 7 day headers are present
    expect(find.text('LUN'), findsOneWidget);
    expect(find.text('MAR'), findsOneWidget);
    expect(find.text('MIÉ'), findsOneWidget);
    expect(find.text('JUE'), findsOneWidget);
    expect(find.text('VIE'), findsOneWidget);
    expect(find.text('SÁB'), findsOneWidget);
    expect(find.text('DOM'), findsOneWidget);

    // Verify chevron navigation buttons exist
    expect(find.byIcon(MoaiIcons.chevronLeft), findsOneWidget);
    expect(find.byIcon(MoaiIcons.chevronRight), findsOneWidget);

    focusNode.dispose();
  });

  testWidgets('focuses Monday (LUN) column upon gaining focus from rail', (tester) async {
    final calendarProvider = CalendarProvider();
    final focusNode = FocusNode();
    bool exitedLeft = false;

    await tester.pumpWidget(
      wrap(
        CalendarEventsPanel(
          focusNode: focusNode,
          onKeyLeft: () {
            exitedLeft = true;
          },
          onKeyRight: () {},
        ),
        calendarProvider: calendarProvider,
      ),
    );
    await tester.pump();

    // Gain focus as if coming from the rail
    focusNode.requestFocus();
    await tester.pump();

    // On LUN (index 0), pressing arrowLeft should exit to the rail
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(exitedLeft, isTrue);

    focusNode.dispose();
  });

  testWidgets('navigates next and previous weeks correctly', (tester) async {
    final calendarProvider = CalendarProvider();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      wrap(
        CalendarEventsPanel(
          focusNode: focusNode,
          onKeyLeft: () {},
          onKeyRight: () {},
        ),
        calendarProvider: calendarProvider,
      ),
    );
    await tester.pump();

    // Initially on current week: return button is not needed
    expect(find.byIcon(MoaiIcons.todayOutlined), findsNothing);

    // Tap Next week
    final nextBtn = find.byIcon(MoaiIcons.chevronRight);
    await tester.tap(nextBtn);
    await tester.pump();

    // In week +1, the "Semana actual" button appears in header actions
    expect(find.byIcon(MoaiIcons.todayOutlined), findsOneWidget);
    expect(find.text('calendar_week_current'), findsOneWidget);

    // Tap "Semana actual" to return
    await tester.tap(find.byIcon(MoaiIcons.todayOutlined));
    await tester.pump();

    // Now tap Prev week to go to -1
    final prevBtn = find.byIcon(MoaiIcons.chevronLeft);
    await tester.tap(prevBtn);
    await tester.pump();

    // At week -1 (limit), chevron_left should no longer be rendered
    expect(find.byIcon(MoaiIcons.chevronLeft), findsNothing);

    focusNode.dispose();
  });

  testWidgets('renders in compact width without RenderFlex overflow', (tester) async {
    FlutterErrorDetails? captured;
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      captured = details;
    };

    final calendarProvider = CalendarProvider();
    await tester.pump();
    calendarProvider.debugSetEvents([
      event('lpf_mon', 'lpf_ar', 'Estudiantes vs Gimnasia LP', 19, 20),
      event('nfl_thu', 'nfl', 'Chiefs vs Broncos', 22, 21),
    ]);
    await calendarProvider.toggleSubscription('lpf_ar');
    await calendarProvider.toggleSubscription('nfl');
    final focusNode = FocusNode();

    // Test with very narrow width (simulating accordion transition / tight constraints)
    await tester.pumpWidget(
      ChangeNotifierProvider<CalendarProvider>.value(
        value: calendarProvider,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: SizedBox(
              width: 250, // Prueba de ancho ultra reducido (w <= 132.5 en title)
              height: 600,
              child: CalendarEventsPanel(
                focusNode: focusNode,
                onKeyLeft: () {},
                onKeyRight: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    FlutterError.onError = oldOnError;
    expect(captured, isNull);
    focusNode.dispose();
  });

  testWidgets('HomeCalendarArea switches from subscriptions to events with Sunday (DOM) focused', (tester) async {
    final calendarProvider = CalendarProvider();
    final areaKey = GlobalKey<HomeCalendarAreaState>();
    int activeIndex = 1; // Start in Subscriptions

    await tester.pumpWidget(
      ChangeNotifierProvider<CalendarProvider>.value(
        value: calendarProvider,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: SizedBox(
              width: 900,
              height: 600,
              child: HomeCalendarArea(
                key: areaKey,
                initialPanelIndex: activeIndex,
                onPanelIndexChanged: (idx) => activeIndex = idx,
                onExitLeft: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Entrar como desde el rail: el área enfoca Suscripciones.
    areaKey.currentState!.requestEntryFocus();
    await tester.pump();

    // Trigger onKeyLeft from inside subscriptions (D-pad left)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    // Active panel should now be 0 (Events)
    expect(activeIndex, 0);

    // Verify Sunday (DOM) is focused: pressing arrowRight should call onKeyRight (go back to subscriptions)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // It should have returned to Subscriptions (panel 1)
    expect(activeIndex, 1);
  });

  testWidgets('renders finished events with FIN badge, solid muted colors, and non-interactive', (tester) async {
    final calendarProvider = CalendarProvider();
    await tester.pump();
    calendarProvider.debugSetEvents([
      event('lpf_mon', 'lpf_ar', 'Estudiantes vs Gimnasia LP', 19, 20),
    ]);
    await calendarProvider.toggleSubscription('lpf_ar');
    final focusNode = FocusNode();

    await tester.pumpWidget(
      wrap(
        CalendarEventsPanel(
          focusNode: focusNode,
          onKeyLeft: () {},
          onKeyRight: () {},
        ),
        calendarProvider: calendarProvider,
      ),
    );
    await tester.pumpAndSettle();

    // In current week, Monday 21 20:00 (Estudiantes vs Gimnasia LP) is in the past
    // It should render with FIN badge (without icon)
    expect(find.text('calendar_status_finished'), findsWidgets);

    // Verify the title is present
    expect(find.text('Estudiantes vs Gimnasia LP'), findsOneWidget);

    // Verify the subscription sport icon (soccer) is present on the card
    expect(find.byIcon(CalendarProvider.getSubscriptionIcon('lpf_ar')), findsWidgets);

    focusNode.dispose();
  });

  testWidgets('renders subscription sport icon matching the event subscription (NFL football)', (tester) async {
    final calendarProvider = CalendarProvider();
    await tester.pump();
    calendarProvider.debugSetEvents([
      event('nfl_thu', 'nfl', 'Chiefs vs Broncos', 22, 21),
    ]);
    await calendarProvider.toggleSubscription('nfl');
    final focusNode = FocusNode();

    await tester.pumpWidget(
      wrap(
        CalendarEventsPanel(
          focusNode: focusNode,
          onKeyLeft: () {},
          onKeyRight: () {},
        ),
        calendarProvider: calendarProvider,
      ),
    );
    await tester.pumpAndSettle();

    // Verify NFL events display the american football icon
    expect(find.byIcon(CalendarProvider.getSubscriptionIcon('nfl')), findsWidgets);

    focusNode.dispose();
  });

  testWidgets('renders pill arrows in dedicated reserved space above and below when day has more than 4 events', (tester) async {
    final calendarProvider = CalendarProvider();
    await tester.pump();
    calendarProvider.debugSetEvents([
      for (var i = 0; i < 5; i++)
        event('lpf_sun_$i', 'lpf_ar', 'Partido $i', 25, 12 + i),
    ]);
    await calendarProvider.toggleSubscription('lpf_ar');
    final focusNode = FocusNode();

    await tester.pumpWidget(
      wrap(
        CalendarEventsPanel(
          focusNode: focusNode,
          onKeyLeft: () {},
          onKeyRight: () {},
        ),
        calendarProvider: calendarProvider,
      ),
    );
    await tester.pumpAndSettle();

    // On Sunday, there are 5 events (> 4), so pill arrow is rendered
    expect(find.byIcon(MoaiIcons.keyboardArrowDown), findsWidgets);

    focusNode.dispose();
  });
}



