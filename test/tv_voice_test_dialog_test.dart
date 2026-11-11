import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons_plus/hugeicons_plus.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/dialogs/tv_voice_test_dialog.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/moai_status_tag.dart';

import 'helpers/real_fonts.dart';
import 'helpers/spanish_translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.infomak.moai.tv/remote_voice');

  setUpAll(() async {
    EasyLocalization.logger.enableBuildModes = [];
    await loadRealFonts();
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
                  },
                ],
              };
            case 'hasPermission':
              return true;
            case 'requestPermission':
              return null;
            case 'startRecording':
              return {'success': true, 'path': '/tmp/test.m4a'};
            case 'stopRecording':
              return {
                'success': true,
                'path': '/tmp/test.m4a',
                'sizeBytes': 12345,
              };
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
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets(
    'TvVoiceTestDialog renders with tip, title, and idle recording button',
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
    },
  );

  testWidgets('TvVoiceTestDialog toggles recording and enters recorded state', (
    tester,
  ) async {
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
    expect(find.byIcon(MoaiIcons.stopCircle), findsOneWidget);

    // Tap stop
    await tester.tap(find.byIcon(MoaiIcons.stopCircle));
    await tester.pumpAndSettle();

    // Now should find play button and amplified badge
    expect(find.text('mic_test_btn_play'), findsOneWidget);
    expect(find.text('mic_test_badge_amplified'), findsOneWidget);
    expect(find.text('mic_test_btn_rerecord'), findsOneWidget);
  });

  testWidgets(
    'en cristal y en castellano: micrófono, etiqueta de estado y sin desbordes',
    (tester) async {
      useSpanishTranslations();
      // Como en el TV: 960×540 puntos.
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(
        wrap(const MoaiGlassScope(child: TvVoiceTestDialog())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // El micrófono liso (no el de rayas) en el encabezado y en el orbe.
      expect(MoaiIcons.mic, HugeIcons.mic02);
      expect(find.byIcon(MoaiIcons.mic), findsNWidgets(2));
      expect(find.byType(MoaiStatusTag), findsNothing);
      expect(find.text('Grabar audio'), findsOneWidget);
      expect(find.byType(TvDialogButton), findsNWidgets(2));

      await tester.tap(find.text('Grabar audio'));
      await tester.pump();
      expect(find.text('GRABANDO'), findsOneWidget);

      await tester.tap(find.byIcon(MoaiIcons.stopCircle));
      await tester.pumpAndSettle();
      expect(find.text('LISTO'), findsOneWidget);
      expect(find.text('Escuchar en TV'), findsOneWidget);
      expect(find.text('Grabar de nuevo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
