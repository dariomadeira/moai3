import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/widgets/dialogs/tv_voice_test_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.infomak.moai.tv/remote_voice');

  setUpAll(() async {
    EasyLocalization.logger.enableBuildModes = [];
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'checkHardware':
          return {
            'devices': [
              {
                'name': 'Remote Control Mic',
                'type': 15,
                'typeName': 'BLE_HEADSET',
              }
            ]
          };
        case 'hasPermission':
          return true;
        case 'requestPermission':
          return null;
        case 'startRecording':
          return {'success': true, 'path': '/tmp/test.m4a'};
        case 'stopRecording':
          return {'success': true, 'path': '/tmp/test.m4a', 'sizeBytes': 12345};
        case 'playRecording':
          return {'success': true};
        case 'stopPlayback':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  testWidgets('TvVoiceTestDialog renders with tip, title, and idle recording button',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(wrap(const TvVoiceTestDialog()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TvVoiceTestDialog), findsOneWidget);
    expect(find.text('mic_test_title'), findsOneWidget);
    expect(find.text('mic_test_tip'), findsOneWidget);
    expect(find.text('mic_test_btn_record'), findsOneWidget);
    expect(find.text('common_close'), findsOneWidget);
  });

  testWidgets('TvVoiceTestDialog toggles recording and enters recorded state',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(wrap(const TvVoiceTestDialog()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap record
    await tester.tap(find.text('mic_test_btn_record'));
    await tester.pump();

    // Now in recording state, should find stop button
    expect(find.textContaining('mic_test_btn_stop'), findsOneWidget);

    // Tap stop
    await tester.tap(find.textContaining('mic_test_btn_stop'));
    await tester.pumpAndSettle();

    // Now should find play button and amplified badge
    expect(find.text('mic_test_btn_play'), findsOneWidget);
    expect(find.text('mic_test_badge_amplified'), findsOneWidget);
    expect(find.text('mic_test_btn_rerecord'), findsOneWidget);
  });
}
