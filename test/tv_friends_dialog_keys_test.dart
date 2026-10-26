import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/widgets/dialogs/tv_friends_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/spanish_translations.dart';
import 'watch_party_provider_test.dart' show FakeWatchPartyService;

void main() {
  /// Abre el panel de amigos con un amigo y deja el foco en su ficha.
  Future<void> openWithFriendFocused(WidgetTester tester) async {
    useSpanishTranslations();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    SharedPreferences.setMockInitialValues({
      'user_code': 'MOAI-1234',
      'device_id': 'tv-1',
    });
    final prefs = await AppPreferences.init();
    final service = FakeWatchPartyService()
      ..mockFriends = [
        FriendInfo(
          deviceId: 'amigo-1',
          userCode: 'MOAI-9999',
          nickname: 'Ana',
          isOnline: false,
        ),
      ];
    final watchParty = WatchPartyProvider(
      preferences: prefs,
      service: service,
      identityService: DeviceIdentityService(prefs),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: watchParty,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => TvFriendsDialog.show(context),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // Foco en la ficha de Ana (como queda al abrir el panel desde el
    // micrófono con OK todavía apretado).
    Focus.of(tester.element(find.text('Ana'))).requestFocus();
    await tester.pumpAndSettle();
  }

  testWidgets('las repeticiones de un OK mantenido no borran al amigo', (
    tester,
  ) async {
    await openWithFriendFocused(tester);

    // OK que se apretó en el micrófono y sigue apretado: llegan repeticiones
    // y después se suelta.
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Eliminar amigo'), findsNothing);
  });

  testWidgets('un OK nuevo sobre el amigo sí pide confirmar el borrado', (
    tester,
  ) async {
    await openWithFriendFocused(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Eliminar amigo'), findsOneWidget);
  });
}
