import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/widgets/cards/channel_grid_tile.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_logo.dart';

void main() {
  final dummyChannelWithEmptyLogo = Channel(
    id: 'test_1',
    name: 'Canal Sin Logo',
    logoUrl: '',
    fallbackUrls: const ['http://test.com/stream'],
    pluginTag: 'DADDY',
  );

  final dummyChannelWithFailedLogo = Channel(
    id: 'test_2',
    name: 'Canal Logo Fallido',
    logoUrl: 'http://example.com/failed_logo.png',
    fallbackUrls: const ['http://test.com/stream'],
    pluginTag: 'DADDY',
  );

  testWidgets('ChannelGridTile muestra etiqueta de nombre cuando logoUrl está vacía', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChannelGridTile(
            channel: dummyChannelWithEmptyLogo,
            isSelected: false,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Canal Sin Logo'), findsOneWidget);
    expect(find.text('DADDY'), findsOneWidget);
  });

  testWidgets('ChannelGridTile muestra etiqueta de nombre cuando la URL del logo falla por timeout/error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChannelGridTile(
            channel: dummyChannelWithFailedLogo,
            isSelected: false,
            onTap: () {},
          ),
        ),
      ),
    );

    // Inicialmente es optimista y no muestra la etiqueta
    expect(find.text('Canal Logo Fallido'), findsNothing);

    // Transcurre el tiempo límite de carga del logo (2.5s)
    await tester.pump(const Duration(milliseconds: 2600));
    await tester.pumpAndSettle();

    // Ahora que el logo falló/caducó el timeout, sí se muestra la etiqueta con el nombre del canal
    expect(find.text('Canal Logo Fallido'), findsOneWidget);
    expect(find.text('DADDY'), findsOneWidget);
  });
}
