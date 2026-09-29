import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/tv_clock_pill.dart';

void main() {
  testWidgets('TvClockPill renders only time text and blinking colon without icon or pill',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TvClockPill(),
        ),
      ),
    );

    // Initial render: no icon, colon present
    expect(find.byType(TvClockPill), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(find.text(':'), findsOneWidget);

    // Verify colon animated opacity changes over time
    final initialOpacity = tester
        .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .opacity;
    expect(initialOpacity, 1.0);

    // Advance 1 second to trigger colon toggle
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));

    final nextOpacity = tester
        .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .opacity;
    expect(nextOpacity, lessThan(1.0));
  });
}
