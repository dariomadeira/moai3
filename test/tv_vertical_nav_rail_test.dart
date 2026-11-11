import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/home_section.dart';
import 'package:moai3/features/home/widgets/tv_vertical_nav_rail.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_svg_icon.dart';
import 'package:provider/provider.dart';

/// Por defecto, con login y catálogo de las 3 secciones.
Widget _wrap(
  Widget child, {
  CalendarProvider? calendarProvider,
  Set<String> catalogSections = const {
    FeaturedMoviesProvider.sectionFeatured,
    FeaturedMoviesProvider.sectionMovies,
    FeaturedMoviesProvider.sectionSeries,
  },
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CalendarProvider>.value(
        value: calendarProvider ?? CalendarProvider(startTicker: false),
      ),
      ChangeNotifierProvider<FeaturedMoviesProvider>(
        create: (_) =>
            FeaturedMoviesProvider()..setAvailableSections(catalogSections),
      ),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TvVerticalNavRail', () {
    testWidgets(
      'muestra los íconos de las secciones visibles sin label vertical',
      (tester) async {
        final scopeNode = FocusScopeNode();
        final focusNode = FocusNode();

        await tester.pumpWidget(
          _wrap(
            TvVerticalNavRail(
              selected: HomeSection.home,
              railScopeNode: scopeNode,
              railFocusNode: focusNode,
              onSelected: (_) {},
              onFocusRight: () {},
              onExit: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(MoaiIcons.railHomeSelected), findsOneWidget);
        expect(find.byIcon(MoaiIcons.railTv), findsOneWidget);
        // Destacados está oculta por ahora (`_hiddenSections`).
        expect(find.byIcon(MoaiIcons.railFeatured), findsNothing);
        expect(find.byIcon(MoaiIcons.railMovies), findsOneWidget);
        // Series va con su SVG (no está en hugeicons_plus).
        expect(find.byType(MoaiSvgIcon), findsOneWidget);
        expect(find.byIcon(MoaiIcons.railCalendar), findsOneWidget);
        expect(find.byIcon(MoaiIcons.railSettings), findsOneWidget);
        expect(find.byIcon(MoaiIcons.railArcade), findsNothing);
        expect(find.byIcon(MoaiIcons.railArcadeSelected), findsNothing);

        // Ya no muestra texto vertical
        expect(find.text('home_rail_home_title'), findsNothing);
        expect(find.text('home_rail_tv_title'), findsNothing);
        expect(find.text('home_rail_featured_title'), findsNothing);
        expect(find.text('home_rail_movies_title'), findsNothing);
        expect(find.text('home_rail_series_title'), findsNothing);
        expect(find.text('home_rail_calendar_title'), findsNothing);
        expect(find.text('home_rail_settings_title'), findsNothing);

        scopeNode.dispose();
        focusNode.dispose();
      },
    );

    testWidgets(
      'D-pad sin Arcade recorre Inicio -> TV -> Películas -> Series -> Agenda -> Descuentos -> Ajustes',
      (tester) async {
        var selected = HomeSection.home;
        final scopeNode = FocusScopeNode();
        final focusNode = FocusNode();

        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (context, setState) {
                return TvVerticalNavRail(
                  selected: selected,
                  railScopeNode: scopeNode,
                  railFocusNode: focusNode,
                  onSelected: (i) => setState(() => selected = i),
                  onFocusRight: () {},
                  onExit: () {},
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        focusNode.requestFocus();
        await tester.pumpAndSettle();

        // Inicio (0) -> TV (1)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(selected, HomeSection.values[1]);

        // TV -> Películas (TV en vivo y Destacados están ocultas)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(selected, HomeSection.movies);

        // Películas -> Series
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(selected, HomeSection.series);

        // Series -> Agenda
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(selected, HomeSection.calendar);

        // Agenda -> Descuentos
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(selected, HomeSection.discounts);

        // Descuentos -> Ajustes (sin Arcade)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(selected, HomeSection.settings);

        scopeNode.dispose();
        focusNode.dispose();
      },
    );

    testWidgets(
      'debajo de Ajustes está Salir: OK llama a onExit y ▲ vuelve a Ajustes',
      (tester) async {
        var selected = HomeSection.settings;
        var exits = 0;
        final scopeNode = FocusScopeNode();
        final focusNode = FocusNode();

        await tester.pumpWidget(
          _wrap(
            StatefulBuilder(
              builder: (context, setState) {
                return TvVerticalNavRail(
                  selected: selected,
                  railScopeNode: scopeNode,
                  railFocusNode: focusNode,
                  onSelected: (i) => setState(() => selected = i),
                  onFocusRight: () {},
                  onExit: () => exits++,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(MoaiIcons.exitApp), findsOneWidget);

        focusNode.requestFocus();
        await tester.pumpAndSettle();

        // Ajustes es la última: ▼ va a Salir; OK no cambia de sección.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(exits, 1);
        expect(selected, HomeSection.settings);

        // ▲ vuelve a Ajustes y ▲ otra vez sube a Descuentos.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(selected, HomeSection.discounts);
        expect(exits, 1);

        scopeNode.dispose();
        focusNode.dispose();
      },
    );

    testWidgets('sin login o catálogo oculta Destacados, Películas y Series; '
        'con catálogo parcial muestra solo lo que bajó', (tester) async {
      var selected = HomeSection.tv;
      final scopeNode = FocusScopeNode();
      final focusNode = FocusNode();

      Future<void> pumpRail(Set<String> sections) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          _wrap(
            catalogSections: sections,
            StatefulBuilder(
              builder: (context, setState) {
                return TvVerticalNavRail(
                  selected: selected,
                  railScopeNode: scopeNode,
                  railFocusNode: focusNode,
                  onSelected: (i) => setState(() => selected = i),
                  onFocusRight: () {},
                  onExit: () {},
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        focusNode.requestFocus();
        await tester.pumpAndSettle();
      }

      Future<void> down() async {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
      }

      // Sin secciones: TV -> Agenda.
      await pumpRail(const {});
      await down();
      expect(selected, HomeSection.calendar);

      // Solo Películas: TV -> Películas -> Agenda.
      selected = HomeSection.tv;
      await pumpRail(const {FeaturedMoviesProvider.sectionMovies});
      await down();
      expect(selected, HomeSection.movies);
      await down();
      expect(selected, HomeSection.calendar);

      // Solo Series: TV -> Series -> Agenda.
      selected = HomeSection.tv;
      await pumpRail(const {FeaturedMoviesProvider.sectionSeries});
      await down();
      expect(selected, HomeSection.series);
      await down();
      expect(selected, HomeSection.calendar);

      scopeNode.dispose();
      focusNode.dispose();
    });
  });
}
