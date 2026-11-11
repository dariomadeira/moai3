import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/channel_browser/widgets/channel_list_panel.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/cards/channel_grid_tile.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_logo.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_focus_ring.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/spanish_translations.dart';

Channel _channel(String id, {String? tag}) => Channel(
  id: id,
  name: 'Canal $id',
  logoUrl: '',
  fallbackUrls: ['http://$id.m3u8'],
  country: 'Argentina',
  category: 'Noticias',
  pluginTag: tag,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<GlobalKey<ChannelListPanelState>> pumpPanel(
    WidgetTester tester,
    List<Channel> channels, {
    Channel? selected,
    Channel? tuned,
    bool tunedIsSelected = true,
    String category = 'Noticias',
  }) async {
    useSpanishTranslations();
    final key = GlobalKey<ChannelListPanelState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 600,
            child: ChannelListPanel(
              key: key,
              selectedCountry: 'Argentina',
              selectedCategory: category,
              channels: channels,
              selectedChannel: selected,
              tunedChannelId: tunedIsSelected ? selected?.id : tuned?.id,
              onSelect: (_) {},
              onLongPress: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  testWidgets('el título nombra la categoría y lleva la ayuda del filtro', (
    tester,
  ) async {
    await pumpPanel(tester, [_channel('1'), _channel('2')]);

    expect(find.text('Canales de Noticias'), findsOneWidget);
    expect(find.text('Mantén pulsado OK para filtrar'), findsOneWidget);
  });

  testWidgets('sin categoría, el título genérico', (tester) async {
    await pumpPanel(tester, [_channel('1'), _channel('2')], category: '');

    expect(find.text('Canales disponibles.'), findsOneWidget);
  });

  testWidgets('las filas llenan el alto sin quedar cortadas', (tester) async {
    await pumpPanel(tester, List.generate(40, (i) => _channel('$i')));

    final tiles = find.byType(ChannelGridTile);
    final count = tiles.evaluate().length;
    expect(count, greaterThanOrEqualTo(4));
    expect(count.isEven, isTrue);

    final subtitleBottom = tester
        .getBottomLeft(find.text('Mantén pulsado OK para filtrar'))
        .dy;
    final firstTop = tester.getTopLeft(tiles.first).dy;
    expect(firstTop, greaterThan(subtitleBottom));
    expect(firstTop - subtitleBottom, lessThan(30));

    final panelBottom = tester.getBottomLeft(find.byType(ChannelListPanel)).dy;
    final lastBottom = tester.getBottomLeft(tiles.at(count - 1)).dy;
    expect(lastBottom, lessThanOrEqualTo(panelBottom));
    expect(panelBottom - lastBottom, lessThan(30));
  });

  testWidgets('sólo el canal elegido lleva el check, sin teñir', (
    tester,
  ) async {
    final channels = [
      _channel('1', tag: 'ar'),
      _channel('2', tag: 'ar'),
      _channel('3'),
    ];
    await pumpPanel(tester, channels, selected: channels[1]);

    final check = find.byIcon(MoaiIcons.selectedCheck);
    expect(check, findsOneWidget);
    expect(
      find.ancestor(
        of: check,
        matching: find.byWidgetPredicate(
          (w) => w is ChannelGridTile && w.channel.id == '2',
        ),
      ),
      findsOneWidget,
    );
    // El check va abajo, debajo del logo: nunca lo pisa.
    final tile = find.byWidgetPredicate(
      (w) => w is ChannelGridTile && w.channel.id == '2',
    );
    final logo = find.descendant(
      of: tile,
      matching: find.byType(TvListCardLeadingLogo),
    );
    expect(
      tester.getTopLeft(check).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(logo).dy),
    );
    expect(
      tester
          .widgetList<MoaiGlass>(find.byType(MoaiGlass))
          .where((g) => g.tint != null),
      isEmpty,
    );
    expect(find.text('AR'), findsNWidgets(2));
  });

  testWidgets('el foco es el anillo del acento, como en Favoritos', (
    tester,
  ) async {
    final channels = List.generate(6, (i) => _channel('$i'));
    final key = await pumpPanel(tester, channels, selected: channels.first);

    key.currentState!.focusSelected();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    final tile = find.byWidgetPredicate(
      (w) => w is ChannelGridTile && w.channel.id == '1',
    );
    final ring = tester.widget<TvFocusRing>(
      find.descendant(of: tile, matching: find.byType(TvFocusRing)),
    );
    expect(ring.focused, isTrue);
  });

  testWidgets('el check sigue al canal sintonizado, no al de la navegación', (
    tester,
  ) async {
    final channels = List.generate(4, (i) => _channel('$i'));
    // Navegando quedó elegido el 0, pero lo que suena es el 2.
    await pumpPanel(
      tester,
      channels,
      selected: channels[0],
      tuned: channels[2],
      tunedIsSelected: false,
    );

    final check = find.byIcon(MoaiIcons.selectedCheck);
    expect(check, findsOneWidget);
    expect(
      find.ancestor(
        of: check,
        matching: find.byWidgetPredicate(
          (w) => w is ChannelGridTile && w.channel.id == '2',
        ),
      ),
      findsOneWidget,
    );

    // Sin nada sintonizado en esta lista: ningún check.
    await pumpPanel(
      tester,
      channels,
      selected: channels[0],
      tunedIsSelected: false,
    );
    expect(find.byIcon(MoaiIcons.selectedCheck), findsNothing);
  });
}
