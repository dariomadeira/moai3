import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moai3/features/settings/screens/friends_screen.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/watch_party_service.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';

void main() {
  late AppPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await AppPreferences.init();
  });

  testWidgets(
      'FriendsScreen renders header, input bar, and single column empty state',
      (tester) async {
    final watchPartyProvider = WatchPartyProvider(
      preferences: prefs,
      service: WatchPartyService(),
      identityService: DeviceIdentityService(prefs),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<WatchPartyProvider>.value(
        value: watchPartyProvider,
        child: const MaterialApp(
          home: FriendsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify input bar TvTextField
    expect(find.byType(TvTextField), findsOneWidget);

    // Verify single-column empty state card
    expect(find.byType(TvEmptyStateCard), findsOneWidget);
  });
}
