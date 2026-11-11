import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/channel_browser/widgets/category_list_panel.dart';
import 'package:moai3/features/channel_browser/widgets/country_list_panel.dart';
import 'package:moai3/features/groups/widgets/group_list_panel.dart';
import 'package:moai3/models/channel_group.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/cards/tv_group_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/spanish_translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<GlobalKey<CountryListPanelState>> pumpPanel(
    WidgetTester tester, {
    required List<String> countries,
    required String selected,
    ValueChanged<String>? onSelect,
    VoidCallback? onLongPress,
  }) async {
    useSpanishTranslations();
    final key = GlobalKey<CountryListPanelState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 600,
            child: CountryListPanel(
              key: key,
              countries: countries,
              selectedCountry: selected,
              tunedCountry: selected,
              onSelect: onSelect ?? (_) {},
              onLongPress: onLongPress ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  testWidgets('el panel de grupos muestra título y la ayuda del filtro', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      countries: const ['Alemania', 'Argentina', 'Brasil'],
      selected: 'Argentina',
    );

    expect(find.text('Grupos de canales'), findsOneWidget);
    expect(find.text('Mantén pulsado OK para filtrar'), findsOneWidget);
  });

  testWidgets('con un solo grupo no se ofrece el filtro', (tester) async {
    await pumpPanel(tester, countries: const ['Argentina'], selected: 'X');

    expect(find.text('Seleccioná un grupo.'), findsOneWidget);
  });

  testWidgets('sólo el grupo elegido lleva el check', (tester) async {
    await pumpPanel(
      tester,
      countries: const ['Alemania', 'Argentina', 'Brasil'],
      selected: 'Argentina',
    );

    final check = find.byIcon(MoaiIcons.selectedCheck);
    expect(check, findsOneWidget);
    expect(
      find.ancestor(
        of: check,
        matching: find.byWidgetPredicate(
          (w) => w is TvGroupTile && w.label == 'Argentina',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('las fichas llenan el alto sin quedar cortadas', (tester) async {
    await pumpPanel(
      tester,
      countries: List.generate(30, (i) => 'Grupo $i'),
      selected: 'Grupo 0',
    );

    final tiles = find.byType(TvGroupTile);
    final count = tiles.evaluate().length;
    expect(count, greaterThan(1));
    final heights = {
      for (var i = 0; i < count; i++) tester.getSize(tiles.at(i)).height,
    };
    // Todas del mismo alto y, como mínimo, la ficha de 48.
    expect(heights.length, 1);
    expect(heights.single, greaterThanOrEqualTo(48));

    // La primera arranca justo bajo el subtítulo (ni cortada ni con hueco)
    // y la última termina dentro del panel.
    final subtitleBottom = tester
        .getBottomLeft(find.text('Mantén pulsado OK para filtrar'))
        .dy;
    final firstTop = tester.getTopLeft(tiles.first).dy;
    expect(firstTop, greaterThan(subtitleBottom));
    expect(firstTop - subtitleBottom, lessThan(30));
    final panelBottom = tester.getBottomLeft(find.byType(CountryListPanel)).dy;
    final lastBottom = tester.getBottomLeft(tiles.at(count - 1)).dy;
    expect(lastBottom, lessThanOrEqualTo(panelBottom));
    expect(panelBottom - lastBottom, lessThan(30));
  });

  testWidgets('OK elige el grupo y OK mantenido abre el filtro', (
    tester,
  ) async {
    String? picked;
    var longPresses = 0;
    final key = await pumpPanel(
      tester,
      countries: const ['Alemania', 'Argentina', 'Brasil'],
      selected: 'Alemania',
      onSelect: (c) => picked = c,
      onLongPress: () => longPresses++,
    );

    key.currentState!.focusSelected();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(picked, 'Argentina');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(longPresses, 1);
  });

  testWidgets('Categorías: mismo encabezado, check y fichas que llenan', (
    tester,
  ) async {
    useSpanishTranslations();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 600,
            child: CategoryListPanel(
              categories: List.generate(20, (i) => 'Categoría $i'),
              selectedCategory: 'Categoría 1',
              tunedCategory: 'Categoría 1',
              onSelect: (_) {},
              onLongPress: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Categorías de canales'), findsOneWidget);
    expect(find.text('Mantén pulsado OK para filtrar'), findsOneWidget);

    final check = find.byIcon(MoaiIcons.selectedCheck);
    expect(check, findsOneWidget);
    expect(
      find.ancestor(
        of: check,
        matching: find.byWidgetPredicate(
          (w) => w is TvGroupTile && w.label == 'Categoría 1',
        ),
      ),
      findsOneWidget,
    );

    final tiles = find.byType(TvGroupTile);
    final count = tiles.evaluate().length;
    final panelBottom = tester.getBottomLeft(find.byType(CategoryListPanel)).dy;
    final lastBottom = tester.getBottomLeft(tiles.at(count - 1)).dy;
    expect(lastBottom, lessThanOrEqualTo(panelBottom));
    expect(panelBottom - lastBottom, lessThan(30));
  });

  testWidgets('Marcadores: mismo encabezado, check y fichas que llenan', (
    tester,
  ) async {
    useSpanishTranslations();
    final groups = List.generate(
      20,
      (i) => ChannelGroup(
        id: 'g$i',
        name: 'Marcador $i',
        icon: '',
        type: 'custom',
        channelIds: ['c$i'],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 600,
            child: GroupListPanel(
              groups: groups,
              selectedGroup: groups[1],
              tunedChannelId: 'c1',
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Marcadores de canales'), findsOneWidget);
    expect(find.text('Mantén pulsado OK para filtrar'), findsOneWidget);

    final check = find.byIcon(MoaiIcons.selectedCheck);
    expect(check, findsOneWidget);
    expect(
      find.ancestor(
        of: check,
        matching: find.byWidgetPredicate(
          (w) => w is TvGroupTile && w.label == 'Marcador 1',
        ),
      ),
      findsOneWidget,
    );

    final tiles = find.byType(TvGroupTile);
    final count = tiles.evaluate().length;
    final panelBottom = tester.getBottomLeft(find.byType(GroupListPanel)).dy;
    final lastBottom = tester.getBottomLeft(tiles.at(count - 1)).dy;
    expect(lastBottom, lessThanOrEqualTo(panelBottom));
    expect(panelBottom - lastBottom, lessThan(30));
  });
}
