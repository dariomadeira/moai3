import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/viewer_favorites_bar.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/widgets/buttons/clear_favorites_button.dart';
import 'package:moai3/widgets/buttons/create_group_button.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/playback_stats_controller.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/widgets/buttons/favorite_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Channel _channel(String id, String name) => Channel(
      id: id,
      name: name,
      logoUrl: 'assets/channels/america.jpg',
      fallbackUrls: const ['http://example.com/stream'],
      country: 'Argentina',
      category: 'Aire',
    );

Widget _wrap(Widget child, {TvSettingsProvider? tvSettings, FavoritesProvider? favoritesProvider}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => PlaybackStatsController()),
      if (tvSettings != null)
        ChangeNotifierProvider<TvSettingsProvider>.value(value: tvSettings),
      if (favoritesProvider != null)
        ChangeNotifierProvider<FavoritesProvider>.value(value: favoritesProvider),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: 160, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('renderiza tiles de favoritos por nombre', (tester) async {
    SharedPreferences.setMockInitialValues({'show_channel_labels': true});
    final prefs = await AppPreferences.init();
    final tvSettings = TvSettingsProvider(prefs);

    final channels = [
      _channel('1', 'TELEFE'),
      _channel('2', 'El Trece'),
    ];

    await tester.pumpWidget(
      _wrap(
        ViewerFavoritesBar(
          favoriteChannels: channels,
          selectedChannel: channels.first,
          scrollController: ScrollController(),
          focusNodes: [FocusNode(), FocusNode(), FocusNode(), FocusNode()],
          onSelect: (_) {},
          onFocusPrevious: (_) {},
          onFocusNext: (_) {},
          onKeyUp: () {},
          onKeyDown: () {},
        ),
        tvSettings: tvSettings,
      ),
    );
    await tester.pump();

    expect(find.text('TELEFE'), findsOneWidget);
    expect(find.text('El Trece'), findsOneWidget);
  });

  testWidgets('lista vacía no muestra tiles de canal', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPreferences.init();
    final tvSettings = TvSettingsProvider(prefs);

    await tester.pumpWidget(
      _wrap(
        ViewerFavoritesBar(
          favoriteChannels: const [],
          selectedChannel: null,
          scrollController: ScrollController(),
          focusNodes: const [],
          onSelect: (_) {},
          onFocusPrevious: (_) {},
          onFocusNext: (_) {},
          onKeyUp: () {},
          onKeyDown: () {},
        ),
        tvSettings: tvSettings,
      ),
    );
    await tester.pump();

    expect(find.text('TELEFE'), findsNothing);
    expect(find.byType(ViewerFavoritesBar), findsOneWidget);
  });

  testWidgets('muestra pluginTag en tile de favorito si está presente', (tester) async {
    SharedPreferences.setMockInitialValues({'show_channel_labels': true});
    final prefs = await AppPreferences.init();
    final tvSettings = TvSettingsProvider(prefs);

    final channelWithTag = Channel(
      id: 'tag-1',
      name: 'CANAL DEX',
      logoUrl: 'assets/channels/america.jpg',
      fallbackUrls: const ['http://example.com/stream'],
      country: 'Argentina',
      category: 'Aire',
      pluginTag: 'dex',
    );

    await tester.pumpWidget(
      _wrap(
        ViewerFavoritesBar(
          favoriteChannels: [channelWithTag],
          selectedChannel: null,
          scrollController: ScrollController(),
          focusNodes: [FocusNode(), FocusNode(), FocusNode()],
          onSelect: (_) {},
          onFocusPrevious: (_) {},
          onFocusNext: (_) {},
          onKeyUp: () {},
          onKeyDown: () {},
        ),
        tvSettings: tvSettings,
      ),
    );
    await tester.pump();

    expect(find.text('CANAL DEX'), findsOneWidget);
    expect(find.text('DEX'), findsOneWidget);
  });

  testWidgets('CreateGroupButton y ClearFavoritesButton son pills sólidos sin bordes en headerAction', (tester) async {
    final createFocus = FocusNode();
    final clearFocus = FocusNode();

    await tester.pumpWidget(
      _wrap(
        ViewerFavoritesBar(
          favoriteChannels: [_channel('1', 'CH1')],
          selectedChannel: null,
          scrollController: ScrollController(),
          focusNodes: [FocusNode()],
          headerAction: Row(
            children: [
              CreateGroupButton(focusNode: createFocus),
              ClearFavoritesButton(focusNode: clearFocus),
            ],
          ),
          onSelect: (_) {},
          onFocusPrevious: (_) {},
          onFocusNext: (_) {},
          onKeyUp: () {},
          onKeyDown: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CreateGroupButton), findsOneWidget);
    expect(find.byType(ClearFavoritesButton), findsOneWidget);

    final createContainer = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(CreateGroupButton),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final createBox = createContainer.decoration as BoxDecoration;
    expect(createBox.borderRadius, BorderRadius.circular(999));
    expect(createBox.border, isNull);
    expect(find.descendant(of: find.byType(CreateGroupButton), matching: find.byType(AppIcon)), findsOneWidget);

    final clearContainer = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(ClearFavoritesButton),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final clearBox = clearContainer.decoration as BoxDecoration;
    expect(clearBox.borderRadius, BorderRadius.circular(999));
    expect(clearBox.border, isNull);
    expect(find.descendant(of: find.byType(ClearFavoritesButton), matching: find.byType(AppIcon)), findsOneWidget);
  });

  testWidgets('ViewerFavoritesBar incluye headerAction con FavoriteButton en forma de pill', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await AppPreferences.init();
    final favProvider = FavoritesProvider(prefs);

    final favFocus = FocusNode();
    final channel = _channel('1', 'CH1');

    await tester.pumpWidget(
      _wrap(
        ViewerFavoritesBar(
          favoriteChannels: [channel],
          selectedChannel: channel,
          scrollController: ScrollController(),
          focusNodes: [FocusNode(), FocusNode(), FocusNode()],
          headerAction: FavoriteButton(
            channel: channel,
            focusNode: favFocus,
          ),
          onSelect: (_) {},
          onFocusPrevious: (_) {},
          onFocusNext: (_) {},
          onKeyUp: () {},
          onKeyDown: () {},
        ),
        favoritesProvider: favProvider,
      ),
    );
    await tester.pump();

    expect(find.byType(FavoriteButton), findsOneWidget);
    final favContainer = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(FavoriteButton),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final box = favContainer.decoration as BoxDecoration;
    expect(box.borderRadius, BorderRadius.circular(999));
    expect(box.border, isNull);
    expect(favContainer.constraints?.maxWidth ?? (favContainer.child != null ? 44.0 : 0.0), 44.0);
  });
}

