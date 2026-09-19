import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/widgets/viewer_favorites_bar.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/playback_stats_controller.dart';
import 'package:provider/provider.dart';

Channel _channel(String id, String name) => Channel(
      id: id,
      name: name,
      logoUrl: 'assets/channels/america.jpg',
      fallbackUrls: const ['http://example.com/stream'],
      country: 'Argentina',
      category: 'Aire',
    );

Widget _wrap(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => PlaybackStatsController(),
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 400, height: 160, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('renderiza tiles de favoritos por nombre', (tester) async {
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
      ),
    );
    await tester.pump();

    expect(find.text('TELEFE'), findsOneWidget);
    expect(find.text('El Trece'), findsOneWidget);
  });

  testWidgets('lista vacía no muestra tiles de canal', (tester) async {
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
      ),
    );
    await tester.pump();

    expect(find.text('TELEFE'), findsNothing);
    expect(find.byType(ViewerFavoritesBar), findsOneWidget);
  });
}

