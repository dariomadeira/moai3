import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/home/areas/home_movies_area.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:provider/provider.dart';

class _FakeFeaturedMoviesProvider extends FeaturedMoviesProvider {
  final List<CategoryColumn> mockCategories;
  final bool mockLoadedOnce;
  final bool mockIsLoading;

  _FakeFeaturedMoviesProvider(
    this.mockCategories, {
    this.mockLoadedOnce = true,
  }) : mockIsLoading = false;

  @override
  List<CategoryColumn> get categories => mockCategories;

  @override
  List<MovieItem> get items =>
      mockCategories.expand((c) => c.movies).toList();

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
    testWidgets('renderiza títulos de categoría y grilla de tarjetas',
        (tester) async {
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
      final provider = _FakeFeaturedMoviesProvider(
        [],
        mockLoadedOnce: false,
      );

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
    });

    testWidgets(
        'muestra TvEmptyStateCard con MoaiIcons.tvMoviesEmpty cuando está cargado pero vacío',
        (tester) async {
      final provider = _FakeFeaturedMoviesProvider(
        [],
      );

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
    });

    testWidgets('soporta parametrización para catálogo de Series con título y vacío personalizado',
        (tester) async {
      final provider = _FakeFeaturedMoviesProvider(
        [],
      );

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
    });
  });
}
