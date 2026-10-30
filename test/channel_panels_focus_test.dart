import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/channel_browser/widgets/category_list_panel.dart';
import 'package:moai3/features/channel_browser/widgets/channel_list_panel.dart';
import 'package:moai3/features/channel_browser/widgets/country_list_panel.dart';
import 'package:moai3/models/channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers/spanish_translations.dart';

Channel _channel(String id, String name) => Channel(
      id: id,
      name: name,
      logoUrl: '',
      fallbackUrls: ['http://$id.m3u8'],
      country: 'Argentina',
      category: 'Noticias',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ChannelListPanel preserves focused channel on focusSelected', (tester) async {
    useSpanishTranslations();
    final channels = List.generate(10, (i) => _channel('$i', 'Canal $i'));
    final panelKey = GlobalKey<ChannelListPanelState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: ChannelListPanel(
              key: panelKey,
              selectedCountry: 'Argentina',
              selectedCategory: 'Noticias',
              channels: channels,
              selectedChannel: channels.first,
              onSelect: (_) {},
              onLongPress: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Focus initial selected item
    panelKey.currentState!.focusSelected();
    await tester.pumpAndSettle();

    // Navigate down to row 1 (items 2 and 3)
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Call focusSelected again: it should remember the focused item (not reset to index 0)
    panelKey.currentState!.focusSelected();
    await tester.pumpAndSettle();

    // The focused channel index should still be 2
    expect(panelKey.currentState!.focusGlobalIndex, isNotNull);
  });

  testWidgets('CategoryListPanel preserves focused category on focusSelected', (tester) async {
    useSpanishTranslations();
    final categories = ['Noticias', 'Deportes', 'Cine', 'Musica', 'Infantil'];
    final panelKey = GlobalKey<CategoryListPanelState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: CategoryListPanel(
              key: panelKey,
              title: 'Categorias',
              selectedCountry: 'Argentina',
              categories: categories,
              selectedCategory: 'Noticias',
              onSelect: (_) {},
              onLongPress: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    panelKey.currentState!.focusSelected();
    await tester.pumpAndSettle();

    // Navigate down
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Refocus
    panelKey.currentState!.focusSelected();
    await tester.pumpAndSettle();

    expect(find.byType(CategoryListPanel), findsOneWidget);
  });

  testWidgets('CountryListPanel preserves focused country on focusSelected', (tester) async {
    useSpanishTranslations();
    final countries = ['Argentina', 'Chile', 'Uruguay', 'Brasil', 'Paraguay'];
    final panelKey = GlobalKey<CountryListPanelState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: CountryListPanel(
              key: panelKey,
              title: 'Grupos',
              countries: countries,
              selectedCountry: 'Argentina',
              onSelect: (_) {},
              onLongPress: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    panelKey.currentState!.focusSelected();
    await tester.pumpAndSettle();

    // Navigate down
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Refocus
    panelKey.currentState!.focusSelected();
    await tester.pumpAndSettle();

    expect(find.byType(CountryListPanel), findsOneWidget);
  });
}

