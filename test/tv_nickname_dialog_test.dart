import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/widgets/dialogs/tv_nickname_dialog.dart';

void main() {
  setUpAll(() async {
    EasyLocalization.logger.enableBuildModes = [];
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  testWidgets('TvNicknameDialog renders with initialNickname and components',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      wrap(
        const TvNicknameDialog(
          initialNickname: 'Juan TV',
          isMandatory: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TvNicknameDialog), findsOneWidget);
    expect(find.text('nickname_dialog_title_setup'), findsOneWidget);
    expect(find.text('nickname_dialog_subtitle_setup'), findsOneWidget);
    expect(find.text('nickname_dialog_label'), findsOneWidget);
    expect(find.text('common_cancel'), findsOneWidget);
    expect(find.text('nickname_dialog_confirm'), findsOneWidget);
  });

  testWidgets('TvNicknameDialog validates empty nickname and displays error',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      wrap(
        const TvNicknameDialog(
          initialNickname: '',
          isMandatory: false,
        ),
      ),
    );
    await tester.pump();

    // Tap confirm button when empty
    await tester.tap(find.text('nickname_dialog_confirm'));
    await tester.pump();

    expect(find.text('nickname_dialog_error_empty'), findsOneWidget);
  });

  testWidgets('TvNicknameDialog returns entered nickname when valid',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    String? result;

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await TvNicknameDialog.show(
                  context,
                  initialNickname: 'Pedro',
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(TvNicknameDialog), findsOneWidget);

    await tester.tap(find.text('nickname_dialog_confirm'));
    await tester.pumpAndSettle();

    expect(find.byType(TvNicknameDialog), findsNothing);
    expect(result, 'Pedro');
  });

  testWidgets('TvNicknameDialog returns null when canceled',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    String? result = 'not_null';

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await TvNicknameDialog.show(
                  context,
                  initialNickname: 'Pedro',
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(TvNicknameDialog), findsOneWidget);

    await tester.tap(find.text('common_cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(TvNicknameDialog), findsNothing);
    expect(result, isNull);
  });
}
