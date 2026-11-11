import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/search/widgets/search_panel.dart';
import 'package:moai3/platform/platform_channels.dart';

import 'helpers/real_fonts.dart';
import 'helpers/spanish_translations.dart';

void main() {
  setUpAll(loadRealFonts);

  late TextEditingController query;
  late FocusNode field;

  Future<void> pump(WidgetTester tester, {String text = ''}) async {
    useSpanishTranslations();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    query = TextEditingController(text: text);
    field = FocusNode(debugLabel: 'field');
    final clear = FocusNode(debugLabel: 'clear');
    addTearDown(query.dispose);
    addTearDown(field.dispose);
    addTearDown(clear.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 800,
            child: ListenableBuilder(
              listenable: query,
              builder: (context, _) => SearchPanel(
                title: 'Buscar',
                queryController: query,
                searchFocusNode: field,
                clearFocusNode: clear,
                searchResults: const [],
                showSearchPrompt: query.text.isEmpty,
                resultsCapped: false,
                selectedChannel: null,
                onFocusUp: () {},
                onLongPress: () {},
                onSelectChannel: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    field.requestFocus();
    await tester.pump();
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey k) async {
    await tester.sendKeyEvent(k);
    await tester.pump();
  }

  String? focused() => FocusManager.instance.primaryFocus?.debugLabel;

  void mockDictation(WidgetTester tester, Future<Object?> Function() result) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(PlatformChannels.remoteVoice, (
      call,
    ) async {
      expect(call.method, 'recognizeSpeech');
      return result();
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        PlatformChannels.remoteVoice,
        null,
      ),
    );
  }

  testWidgets('→ va al micrófono y lo dictado queda en el campo', (
    tester,
  ) async {
    await pump(tester);
    mockDictation(tester, () async => ' TN ');

    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'search_mic');
    await key(tester, LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump();

    expect(query.text, 'TN');
    expect(focused(), 'field');
  });

  testWidgets('si se cancela el dictado no cambia nada', (tester) async {
    await pump(tester);
    mockDictation(tester, () async => null);

    await key(tester, LogicalKeyboardKey.arrowRight);
    await key(tester, LogicalKeyboardKey.select);
    await tester.pump();

    expect(query.text, isEmpty);
    expect(focused(), 'search_mic');
  });

  testWidgets('con texto: campo → micrófono → X, y ← vuelve', (tester) async {
    await pump(tester, text: 'cine');

    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'search_mic');
    await key(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'clear');
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(focused(), 'search_mic');
    await key(tester, LogicalKeyboardKey.arrowLeft);
    expect(focused(), 'field');
  });
}
