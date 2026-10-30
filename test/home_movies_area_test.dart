import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/areas/home_movies_area.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/features/movies/screens/movie_category_screen.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFeaturedMoviesProvider extends FeaturedMoviesProvider {
  final List<CategoryColumn> mockCategories;
  final bool mockLoadedOnce;
  final bool mockIsLoading;

  _FakeFeaturedMoviesProvider(this.mockCategories, {this.mockLoadedOnce = true})
    : mockIsLoading = false;

  @override
  List<CategoryColumn> get categories => mockCategories;

  @override
  List<MovieItem> get items => mockCategories.expand((c) => c.movies).toList();

  @override
  bool get loadedOnce => mockLoadedOnce;

  @override
  bool get isLoading => mockIsLoading;

  @override
  String? get errorMessage => null;

  @override
  List<CategoryColumn> categoriesFor(String section) => mockCategories;

  @override
  List<MovieItem> itemsFor(String section) =>
      mockCategories.expand((c) => c.movies).toList();

  @override
  bool loadedOnceFor(String section) => mockLoadedOnce;

  @override
  bool isLoadingFor(String section) => mockIsLoading;

  @override
  String? errorMessageFor(String section) => null;

  @override
  Future<void> loadSection(String section, {bool force = false}) async {}

  @override
  Future<void> loadFeatured({bool force = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeMoviesArea Tests (Opción B)', () {
    testWidgets('renderiza títulos de categoría y grilla de tarjetas', (
      tester,
    ) async {
      final fakeCategories = [
        CategoryColumn(
          columnId: 101,
          columnName: "A Hero's Final Hour",
          movies: List.generate(
            10,
            (i) => MovieItem(
              contentId: 'movie_1_$i',
              name: 'Película Hero $i',
              poster: 'https://example.com/poster_$i.jpg',
              year: '2026',
              score: '8.5',
            ),
          ),
        ),
        CategoryColumn(
          columnId: 102,
          columnName: 'Child of the Wild',
          movies: List.generate(
            5,
            (i) => MovieItem(
              contentId: 'movie_2_$i',
              name: 'Película Wild $i',
              poster: 'https://example.com/poster_wild_$i.jpg',
              year: '2025',
              score: '7.2',
            ),
          ),
        ),
      ];

      final provider = _FakeFeaturedMoviesProvider(fakeCategories);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1920,
              height: 1080,
              child: ChangeNotifierProvider<FeaturedMoviesProvider>.value(
                value: provider,
                child: HomeMoviesArea(onExitLeft: () {}),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verificar que los títulos de categoría aparecen en pantalla
      expect(find.text("A Hero's Final Hour"), findsOneWidget);
      expect(find.text('Child of the Wild'), findsOneWidget);

      // Verificar que las películas están presentes
      expect(find.text('Película Hero 0'), findsOneWidget);
      expect(find.text('Película Hero 4'), findsOneWidget);
    });

    testWidgets(
      'muestra CircularProgressIndicator y no TvEmptyStateCard cuando no ha cargado',
      (tester) async {
        final provider = _FakeFeaturedMoviesProvider([], mockLoadedOnce: false);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1920,
                height: 1080,
                child: ChangeNotifierProvider<FeaturedMoviesProvider>.value(
                  value: provider,
                  child: HomeMoviesArea(onExitLeft: () {}),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byIcon(MoaiIcons.tvMoviesEmpty), findsNothing);
      },
    );

    testWidgets(
      'muestra TvEmptyStateCard con MoaiIcons.tvMoviesEmpty cuando está cargado pero vacío',
      (tester) async {
        final provider = _FakeFeaturedMoviesProvider([]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1920,
                height: 1080,
                child: ChangeNotifierProvider<FeaturedMoviesProvider>.value(
                  value: provider,
                  child: HomeMoviesArea(onExitLeft: () {}),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byIcon(MoaiIcons.tvMoviesEmpty), findsOneWidget);
      },
    );

    testWidgets(
      'soporta parametrización para catálogo de Series con título y vacío personalizado',
      (tester) async {
        final provider = _FakeFeaturedMoviesProvider([]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1920,
                height: 1080,
                child: ChangeNotifierProvider<FeaturedMoviesProvider>.value(
                  value: provider,
                  child: HomeMoviesArea(
                    section: FeaturedMoviesProvider.sectionSeries,
                    panelTitle: 'Series',
                    accordionIcon: MoaiIcons.tvAccordionSeries,
                    emptyMessage: 'No hay series disponibles en el catálogo.',
                    onExitLeft: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Series'), findsOneWidget);
        expect(find.byIcon(MoaiIcons.tvAccordionSeries), findsOneWidget);
        expect(
          find.text('No hay series disponibles en el catálogo.'),
          findsOneWidget,
        );
      },
    );
  });

  group('grilla perezosa', () {
    /// Una categoría de 60 películas (12 filas) en una pantalla de TV.
    Future<GlobalKey<HomeMoviesAreaState>> pumpBigGrid(
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.reset());
      final key = GlobalKey<HomeMoviesAreaState>();
      final provider = _FakeFeaturedMoviesProvider([
        CategoryColumn(
          columnId: 1,
          columnName: 'Muchas',
          movies: List.generate(
            60,
            (i) => MovieItem(contentId: 'm$i', name: 'Película $i'),
          ),
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<FeaturedMoviesProvider>.value(
              value: provider,
              child: HomeMoviesArea(key: key, onExitLeft: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return key;
    }

    testWidgets('no arma todas las tarjetas de una categoría grande', (
      tester,
    ) async {
      await pumpBigGrid(tester);
      expect(find.text('Película 0'), findsOneWidget);
      // Las últimas filas no se arman hasta acercarse.
      expect(find.text('Película 59'), findsNothing);
    });

    testWidgets('↓ baja fila por fila hasta la última', (tester) async {
      final key = await pumpBigGrid(tester);
      key.currentState!.focusGrid();
      await tester.pumpAndSettle();
      for (var i = 0; i < 11; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'movies_grid');
      expect(key.currentState!.debugSelection, (0, 11, 0));
      expect(find.text('Película 55'), findsOneWidget);
    });

    testWidgets(
      '"Ver todas" ocupa el último casillero y OK abre la categoría',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await AppPreferences.init();
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.reset());
        final key = GlobalKey<HomeMoviesAreaState>();
        final provider = _FakeFeaturedMoviesProvider([
          CategoryColumn(
            columnId: 76275,
            columnName: 'Acción',
            hasMore: true,
            movies: List.generate(
              9,
              (i) => MovieItem(contentId: 'a$i', name: 'Acción $i'),
            ),
          ),
        ]);
        // Los providers van arriba de MaterialApp, como en la app: la
        // pantalla de la categoría es otra ruta.
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<FeaturedMoviesProvider>.value(
                value: provider,
              ),
              ChangeNotifierProvider(create: (_) => TvSettingsProvider(prefs)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: HomeMoviesArea(key: key, onExitLeft: () {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 9 películas + la tarjeta = 2 filas completas; sin el contador.
        expect(find.byType(TvShowAllCard), findsOneWidget);
        expect(find.text('9'), findsNothing);

        key.currentState!.focusGrid();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        for (var i = 0; i < 4; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
        }
        expect(key.currentState!.debugSelection, (0, 1, 4));
        expect(
          tester.widget<TvShowAllCard>(find.byType(TvShowAllCard)).isSelected,
          isTrue,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();
        expect(find.byType(MovieCategoryScreen), findsOneWidget);
        expect(
          tester
              .widget<MovieCategoryScreen>(find.byType(MovieCategoryScreen))
              .category
              .columnId,
          76275,
        );
      },
    );

    testWidgets('al volver a la grilla conserva la elección y el scroll', (
      tester,
    ) async {
      final key = await pumpBigGrid(tester);
      key.currentState!.focusGrid();
      await tester.pumpAndSettle();
      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
      }
      // Sale de la grilla (p. ej. al rail) y vuelve.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      key.currentState!.focusGrid();
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'movies_grid');
      expect(key.currentState!.debugSelection, (0, 8, 0));
      expect(find.text('Película 40'), findsOneWidget);
    });
  });
}
