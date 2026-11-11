import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/settings/widgets/settings_about_panel.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/real_fonts.dart';
import 'helpers/spanish_translations.dart';

/// Películas disponibles con un total fijo; cuenta los pedidos.
class _FakeMovies extends FeaturedMoviesProvider {
  _FakeMovies({required this.available, this.total, this.seasons});

  final bool available;
  final int? total;

  /// Total de "Todos" de Series (temporadas).
  final int? seasons;
  int requests = 0;

  @override
  bool isSectionAvailable(String section) => available;

  @override
  int? get libraryTotal =>
      libraryTotalFor(FeaturedMoviesProvider.sectionMovies);

  @override
  int? libraryTotalFor(String section) => requests == 0
      ? null
      : section == FeaturedMoviesProvider.sectionSeries
      ? seasons
      : total;

  @override
  Future<void> loadLibraryTotal({
    String section = FeaturedMoviesProvider.sectionMovies,
  }) async {
    requests++;
    notifyListeners();
  }
}

void main() {
  setUpAll(loadRealFonts);
  late AppPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await AppPreferences.init();
  });

  Future<void> pump(WidgetTester tester, FeaturedMoviesProvider? movies) async {
    useSpanishTranslations();
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final panel = SettingsAboutPanel(focusNode: FocusNode(), onKeyLeft: () {});
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ChannelProvider(prefs)),
          if (movies != null)
            ChangeNotifierProvider<FeaturedMoviesProvider>.value(value: movies),
        ],
        child: MaterialApp(home: Scaffold(body: panel)),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('muestra el total de películas de la biblioteca', (tester) async {
    final movies = _FakeMovies(available: true, total: 31419);
    await pump(tester, movies);
    expect(movies.requests, 2);
    expect(find.text('Películas disponibles'), findsOneWidget);
    expect(find.text('31.419 películas'), findsOneWidget);
  });

  testWidgets('con "Todos" en Series muestra las temporadas', (tester) async {
    final movies = _FakeMovies(available: true, total: 31419, seasons: 12345);
    await pump(tester, movies);
    expect(movies.requests, 2);
    expect(find.text('Temporadas disponibles'), findsOneWidget);
    expect(find.text('12.345 temporadas'), findsOneWidget);
  });

  testWidgets('sin total de Series no hay fila de temporadas', (tester) async {
    await pump(tester, _FakeMovies(available: true, total: 31419));
    expect(find.text('Películas disponibles'), findsOneWidget);
    expect(find.text('Temporadas disponibles'), findsNothing);
  });

  testWidgets('sin catálogo de películas no muestra la fila', (tester) async {
    await pump(tester, _FakeMovies(available: false));
    expect(find.text('Películas disponibles'), findsNothing);
    expect(find.text('Canales cargados'), findsOneWidget);
  });

  testWidgets('sin el provider de películas sigue andando', (tester) async {
    await pump(tester, null);
    expect(find.text('Películas disponibles'), findsNothing);
    expect(find.text('Buscar actualizaciones'), findsOneWidget);
  });
}
