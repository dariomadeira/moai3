import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/home_friend_requests_card.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/spanish_translations.dart';
import 'watch_party_provider_test.dart' show FakeWatchPartyService;

FriendInfo _request(String name) => FriendInfo(
  deviceId: name.toLowerCase(),
  userCode: 'MOAI-${name.toUpperCase()}',
  nickname: name,
  isOnline: true,
);

void main() {
  /// La tarjeta del tamaño de una del Inicio en el Chromecast (960×540 a
  /// densidad 2), con el foco puesto.
  Future<FakeWatchPartyService> pumpItem(
    WidgetTester tester,
    List<FriendInfo> requests,
  ) async {
    useSpanishTranslations();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.reset());
    SharedPreferences.setMockInitialValues({
      'device_user_code': 'MOAI-1234',
      'device_id': 'tv-1',
    });
    final prefs = await AppPreferences.init();
    final svc = FakeWatchPartyService()
      ..mockRequests = requests
      ..mockIncoming = {for (final r in requests) r.deviceId};
    final watchParty = WatchPartyProvider(
      preferences: prefs,
      service: svc,
      identityService: DeviceIdentityService(prefs),
    );
    await watchParty.loadFriends();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: watchParty,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 810,
                height: 99,
                child: HomeFriendRequestsItem(
                  focusNode: focus,
                  onKeyLeft: () {},
                  onKeyUp: () {},
                  onKeyDown: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    return svc;
  }

  testWidgets('muestra las solicitudes y cuántas son', (tester) async {
    await pumpItem(tester, [_request('Caro'), _request('Dani')]);
    expect(find.text('Solicitudes'), findsOneWidget);
    expect(find.text('2 solicitudes'), findsOneWidget);
    expect(find.text('Caro'), findsOneWidget);
    expect(find.text('Dani'), findsOneWidget);
    // La elegida (con foco) dice qué hace OK; la otra, que quiere ser amigo.
    expect(find.text('OK acepta · Mantené OK: rechaza'), findsOneWidget);
    expect(find.text('Quiere ser tu amigo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OK acepta la elegida (→ elige la siguiente)', (tester) async {
    final svc = await pumpItem(tester, [_request('Caro'), _request('Dani')]);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(svc.mockFriends.map((f) => f.userCode), ['MOAI-DANI']);
    expect(find.text('Ahora sos amigo de Dani.'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('OK mantenido pide confirmar y la rechaza', (tester) async {
    final svc = await pumpItem(tester, [_request('Caro')]);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Rechazar solicitud'), findsOneWidget);

    // Cancelar está enfocado: → Rechazar y OK.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(svc.rejected, ['caro']);
    expect(svc.mockFriends, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
