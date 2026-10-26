import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/features/home/areas/home_dashboard_area.dart';
import 'package:moai3/features/home/widgets/home_continue_card.dart';
import 'package:moai3/features/home/widgets/home_movie_strip.dart';
import 'package:moai3/features/home/widgets/home_trailers_card.dart';
import 'package:moai3/features/home/widgets/home_watchlist_card.dart';
import 'package:moai3/features/movies/screens/movie_detail_screen.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/services/calendar/argentina_time.dart';
import 'package:moai3/features/home/widgets/home_events_card.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/movie_progress_service.dart';
import 'package:moai3/services/movie_watchlist_service.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/tv_common/tv_press_detector.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'featured_movies_trailers_test.dart' show writeMoviesCatalog;
import 'helpers/spanish_translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    MovieWatchlistService.instance.resetForTest();
    prefs = await AppPreferences.init();
  });

  /// Inicio a 1080p. [moviesVisible]: si Películas está en el rail.
  /// [onTv]: como en el Chromecast (960×540 puntos a densidad 2), con el
  /// panel del tamaño que le deja el rail.
  Future<void> pumpHome(
    WidgetTester tester, {
    bool moviesVisible = true,
    FeaturedMoviesProvider? catalog,
    bool onTv = false,
    CalendarProvider? calendar,
  }) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = onTv ? 2.0 : 1.0;
    addTearDown(() => tester.view.reset());
    final panel = onTv ? const Size(840, 510) : const Size(1920, 1080);

    final movies =
        catalog ??
        (FeaturedMoviesProvider()..setAvailableSections({
          if (moviesVisible) FeaturedMoviesProvider.sectionMovies,
        }));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          if (calendar != null)
            ChangeNotifierProvider.value(value: calendar)
          else
            ChangeNotifierProvider(
              create: (_) =>
                  CalendarProvider(preferences: prefs, startTicker: false),
            ),
          ChangeNotifierProvider.value(value: movies),
          // Para el detalle de la película.
          ChangeNotifierProvider(create: (_) => TvSettingsProvider(prefs)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: panel.width,
              height: panel.height,
              child: HomeDashboardArea(
                onExitLeft: () {},
                romManager: ArcadeRomManagerService(preferences: prefs),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> addToWatchlist(List<String> names) async {
    // toggle agrega adelante: el primero de [names] queda primero.
    for (final (i, name) in names.indexed.toList().reversed) {
      await MovieWatchlistService.instance.toggle(
        MovieItem(contentId: 'm$i', name: name),
      );
    }
  }

  /// Baja con ↓ por la lista del Inicio hasta "Películas a ver"
  /// (clima → eventos → Interesantes).
  Future<void> focusWatchlist(WidgetTester tester) async {
    final watchlistNode = tester
        .widget<TvPressDetector>(
          find.ancestor(
            of: find.byType(HomeWatchlistCard),
            matching: find.byType(TvPressDetector),
          ),
        )
        .focusNode!;
    for (var i = 0; i < 4 && !watchlistNode.hasPrimaryFocus; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
    }
    expect(watchlistNode.hasPrimaryFocus, isTrue);
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Future<void> longPressOk(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump(TvTiming.longPress + const Duration(milliseconds: 50));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
  }

  group('HomeDashboardArea', () {
    testWidgets('renderiza panel único Inicio a ancho completo', (
      tester,
    ) async {
      await pumpHome(tester);

      // Debe mostrar el icono del panel y el título Inicio
      expect(find.byIcon(MoaiIcons.tvAccordionHome), findsOneWidget);
      expect(find.text('home_panel_home_title'), findsWidgets);
    });
  });

  group('Interesantes', () {
    testWidgets('no aparece si Películas no está en el rail', (tester) async {
      await addToWatchlist(['Coco']);
      await pumpHome(tester, moviesVisible: false);
      expect(find.byType(HomeWatchlistCard), findsNothing);
    });

    testWidgets('vacía explica cómo agregarlas', (tester) async {
      useSpanishTranslations();
      await pumpHome(tester);

      expect(find.text('Interesantes'), findsOneWidget);
      expect(
        find.text(
          'Tocá «Marcar como interesante» en el detalle de una película para tenerla acá.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('muestra la lista y se actualiza al agregar una', (
      tester,
    ) async {
      useSpanishTranslations();
      await pumpHome(tester);
      expect(find.text('Coco'), findsNothing);

      await addToWatchlist(['Coco', 'Up']);
      await tester.pumpAndSettle();
      expect(find.text('Coco'), findsOneWidget);
      expect(find.text('Up'), findsOneWidget);
      expect(find.text('2 películas'), findsOneWidget);
    });

    testWidgets('con foco en una película avisa que mantener OK la quita', (
      tester,
    ) async {
      useSpanishTranslations();
      await addToWatchlist(['Coco', 'Up']);
      await pumpHome(tester);
      expect(find.text('2 películas'), findsOneWidget);
      expect(find.text('Quitar todas'), findsOneWidget);

      await focusWatchlist(tester);
      expect(find.text('Mantené OK para quitar'), findsOneWidget);

      // En el botón "Quitar todas" el aviso no corresponde.
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(find.text('Mantené OK para quitar'), findsNothing);
    });

    testWidgets('una empezada sale de Interesantes y va a Seguir viendo', (
      tester,
    ) async {
      useSpanishTranslations();
      await addToWatchlist(['Coco', 'Up']);
      // Coco (m0) quedó en curso de antes, cuando seguía en las dos.
      await tester.runAsync(
        () => MovieProgressService.saveProgress(
          contentId: 'm0',
          currentPosition: const Duration(minutes: 30),
          totalDuration: const Duration(minutes: 120),
          movie: MovieItem(contentId: 'm0', name: 'Coco'),
        ),
      );
      await pumpHome(tester);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      // Interesantes queda cuarta (fuera de la ventana): basta la lista.
      expect(MovieWatchlistService.instance.movies.map((m) => m.name), ['Up']);
      final continueCard = tester.widget<HomeContinueCard>(
        find.byType(HomeContinueCard),
      );
      expect(continueCard.movies.map((m) => m.name), ['Coco']);
    });

    testWidgets('OK va directo al detalle de la película, sin diálogo', (
      tester,
    ) async {
      useSpanishTranslations();
      await addToWatchlist(['Coco', 'Up']);
      await pumpHome(tester);
      await focusWatchlist(tester);

      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.enter);

      expect(find.byType(TvDialog), findsNothing);
      final detail = tester.widget<MovieDetailScreen>(
        find.byType(MovieDetailScreen),
      );
      expect(detail.movie.name, 'Up');
    });

    testWidgets('mantener OK pide confirmar y quita sólo esa película', (
      tester,
    ) async {
      useSpanishTranslations();
      await addToWatchlist(['Coco', 'Up']);
      await pumpHome(tester);
      await focusWatchlist(tester);

      await longPressOk(tester);
      expect(find.text('¿Quitar de Interesantes?'), findsOneWidget);
      expect(find.text('«Coco» sale de tu lista.'), findsOneWidget);
      expect(find.byType(MovieDetailScreen), findsNothing);

      // Cancelar arranca con el foco: OK no quita nada.
      await press(tester, LogicalKeyboardKey.enter);
      expect(MovieWatchlistService.instance.movies, hasLength(2));

      await longPressOk(tester);
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();

      expect(MovieWatchlistService.instance.movies.map((m) => m.name), ['Up']);
      expect(find.text('Coco'), findsNothing);
      expect(find.text('Up'), findsOneWidget);
    });

    testWidgets('← desde la primera va a Quitar todas y pide confirmación', (
      tester,
    ) async {
      useSpanishTranslations();
      await addToWatchlist(['Coco', 'Up', 'Wall-E']);
      await pumpHome(tester);
      await focusWatchlist(tester);

      await press(tester, LogicalKeyboardKey.arrowLeft);
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.text('¿Quitar todas de Interesantes?'), findsOneWidget);

      // Cancelar arranca con el foco: OK no borra nada.
      await press(tester, LogicalKeyboardKey.enter);
      expect(MovieWatchlistService.instance.movies, hasLength(3));

      await press(tester, LogicalKeyboardKey.enter);
      await tester.tap(find.text('Quitar todas').last);
      await tester.pumpAndSettle();

      expect(MovieWatchlistService.instance.movies, isEmpty);
      expect(
        find.text(
          'Tocá «Marcar como interesante» en el detalle de una película para tenerla acá.',
        ),
        findsOneWidget,
      );
      expect(find.text('Quitar todas'), findsNothing);
    });
  });

  group('Adelantos', () {
    /// Provider con el catálogo de prueba ya cargado (lectura real de disco).
    Future<FeaturedMoviesProvider> loadedCatalog(WidgetTester tester) async {
      final provider = FeaturedMoviesProvider()
        ..setAvailableSections({FeaturedMoviesProvider.sectionMovies});
      await tester.runAsync(() async {
        final dir = await writeMoviesCatalog();
        addTearDown(() => dir.deleteSync(recursive: true));
        MoiamovApiService.instance.debugSetCatalogDirectory(dir);
        addTearDown(
          () => MoiamovApiService.instance.debugSetCatalogDirectory(null),
        );
        await provider.loadSection(FeaturedMoviesProvider.sectionMovies);
      });
      return provider;
    }

    /// Baja con ↓ hasta "Adelantos": es la cuarta tarjeta y el Inicio
    /// muestra tres a la vez, así que recién se dibuja al llegar.
    Future<void> focusTrailers(WidgetTester tester) async {
      bool focused() {
        final card = find.ancestor(
          of: find.byType(HomeTrailersCard),
          matching: find.byType(TvPressDetector),
        );
        return card.evaluate().isNotEmpty &&
            tester.widget<TvPressDetector>(card).focusNode!.hasPrimaryFocus;
      }

      for (var i = 0; i < 6 && !focused(); i++) {
        await press(tester, LogicalKeyboardKey.arrowDown);
      }
      expect(focused(), isTrue);
    }

    testWidgets('sin adelantos no aparece', (tester) async {
      await pumpHome(tester);
      expect(find.byType(HomeTrailersCard), findsNothing);
    });

    testWidgets('muestra los adelantos sin la marca "(Tráiler)"', (
      tester,
    ) async {
      useSpanishTranslations();
      await pumpHome(tester, catalog: await loadedCatalog(tester));
      await focusTrailers(tester);

      expect(find.text('Adelantos'), findsOneWidget);
      // Con foco, en lugar de cuántos hay va el aviso.
      expect(find.text('Presioná OK para verlo'), findsOneWidget);
      expect(find.text('Weapons'), findsOneWidget);
      expect(find.text('Superman'), findsOneWidget);
    });

    testWidgets('con el ajuste apagado la tarjeta no aparece', (tester) async {
      useSpanishTranslations();
      final catalog = await loadedCatalog(tester);
      expect(
        catalog.trailersFor(FeaturedMoviesProvider.sectionMovies),
        isNotEmpty,
      );
      await prefs.saveBool('home_show_trailers', false);
      await pumpHome(tester, catalog: catalog);
      expect(find.byType(HomeTrailersCard), findsNothing);
    });

    testWidgets('→ elige el siguiente y OK abre el detalle del adelanto', (
      tester,
    ) async {
      useSpanishTranslations();
      await pumpHome(tester, catalog: await loadedCatalog(tester));
      await focusTrailers(tester);
      expect(find.text('Presioná OK para verlo'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.enter);

      final detail = tester.widget<MovieDetailScreen>(
        find.byType(MovieDetailScreen),
      );
      expect(detail.movie.contentId, 't2');
      expect(find.text('Adelanto - Superman'), findsOneWidget);
    });
  });

  group('MovieWatchlistService', () {
    test('guarda la película entera y la relee igual', () async {
      await MovieWatchlistService.instance.toggle(
        MovieItem(
          contentId: '7',
          name: 'Interstellar',
          backdrop: 'https://example.com/a.jpg',
          backdrops: const ['https://example.com/b.jpg'],
          score: '8.7',
        ),
      );

      MovieWatchlistService.instance.resetForTest();
      await MovieWatchlistService.instance.ensureLoaded();
      final movie = MovieWatchlistService.instance.movies.single;
      expect(movie.name, 'Interstellar');
      expect(movie.score, '8.7');
      expect(movie.distinctBackdrops, [
        'https://example.com/a.jpg',
        'https://example.com/b.jpg',
      ]);
    });

    test('la última marcada va primero y toggle la quita', () async {
      final service = MovieWatchlistService.instance;
      await service.toggle(MovieItem(contentId: '1', name: 'Uno'));
      await service.toggle(MovieItem(contentId: '2', name: 'Dos'));
      expect(service.movies.map((m) => m.contentId), ['2', '1']);

      expect(
        await service.toggle(MovieItem(contentId: '2', name: 'Dos')),
        isFalse,
      );
      expect(service.movies.map((m) => m.contentId), ['1']);
    });
  });

  group('Seguir viendo', () {
    /// Deja [names] empezadas (la primera, la última vista) con la película
    /// guardada en el progreso.
    Future<void> startWatching(WidgetTester tester, List<String> names) =>
        tester.runAsync(() async {
          for (final (i, name) in names.indexed.toList().reversed) {
            await MovieProgressService.saveProgress(
              contentId: 'c$i',
              currentPosition: const Duration(minutes: 60),
              totalDuration: const Duration(minutes: 120),
              movie: MovieItem(contentId: 'c$i', name: name),
            );
            await Future<void>.delayed(const Duration(milliseconds: 1100));
          }
        });

    Future<void> focusContinue(WidgetTester tester) async {
      final node = tester
          .widget<TvPressDetector>(
            find.ancestor(
              of: find.byType(HomeContinueCard),
              matching: find.byType(TvPressDetector),
            ),
          )
          .focusNode!;
      for (var i = 0; i < 4 && !node.hasPrimaryFocus; i++) {
        await press(tester, LogicalKeyboardKey.arrowDown);
      }
      expect(node.hasPrimaryFocus, isTrue);
    }

    Future<void> settleLoads(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sin nada empezado no aparece', (tester) async {
      useSpanishTranslations();
      await pumpHome(tester);
      expect(find.byType(HomeContinueCard), findsNothing);
    });

    testWidgets('muestra las empezadas con su barra, la última primero', (
      tester,
    ) async {
      useSpanishTranslations();
      await startWatching(tester, ['Coco', 'Up']);
      await pumpHome(tester);
      await settleLoads(tester);

      final card = tester.widget<HomeContinueCard>(
        find.byType(HomeContinueCard),
      );
      expect(card.movies.map((m) => m.name), ['Coco', 'Up']);
      expect(card.watched['c0'], closeTo(0.5, 0.001));
      expect(find.text('Seguir viendo'), findsOneWidget);
    });

    testWidgets('no aparece si Películas no está en el rail', (tester) async {
      useSpanishTranslations();
      await startWatching(tester, ['Coco']);
      await pumpHome(tester, moviesVisible: false);
      await settleLoads(tester);
      expect(find.byType(HomeContinueCard), findsNothing);
    });

    testWidgets('mantener OK la marca como vista y sale de Interesantes', (
      tester,
    ) async {
      useSpanishTranslations();
      await startWatching(tester, ['Coco', 'Up']);
      await MovieWatchlistService.instance.toggle(
        MovieItem(contentId: 'c0', name: 'Coco'),
      );
      await pumpHome(tester);
      await settleLoads(tester);
      await focusContinue(tester);

      await longPressOk(tester);
      expect(find.text('¿Marcar como vista?'), findsOneWidget);
      await tester.tap(find.text('Marcar como vista'));
      await tester.pumpAndSettle();
      await settleLoads(tester);

      final card = tester.widget<HomeContinueCard>(
        find.byType(HomeContinueCard),
      );
      expect(card.movies.map((m) => m.name), ['Up']);
      expect(MovieWatchlistService.instance.contains('c0'), isFalse);
      final progress = await tester.runAsync(
        () => MovieProgressService.getProgress('c0'),
      );
      expect(progress?.isCompleted, isTrue);
    });

    testWidgets('← y OK en "Marcar todo como visto" la vacía y desaparece', (
      tester,
    ) async {
      useSpanishTranslations();
      await startWatching(tester, ['Coco', 'Up']);
      await pumpHome(tester);
      await settleLoads(tester);
      await focusContinue(tester);

      await press(tester, LogicalKeyboardKey.arrowLeft);
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.text('¿Marcar todo como visto?'), findsOneWidget);
      await tester.tap(find.text('Marcar todas'));
      await tester.pumpAndSettle();
      await settleLoads(tester);

      expect(find.byType(HomeContinueCard), findsNothing);
    });
  });

  group('HomeMovieStrip', () {
    Future<void> pumpStrip(WidgetTester tester, {String? loadingId}) async {
      tester.view.physicalSize = const Size(1600, 400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.reset());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 700,
              height: 108,
              child: HomeMovieStrip(
                movies: [
                  MovieItem(
                    contentId: 'a',
                    name: 'Coco',
                    backdrops: const ['https://img.test/a.jpg'],
                  ),
                  MovieItem(
                    contentId: 'b',
                    name: 'Up',
                    backdrops: const ['https://img.test/b.jpg'],
                  ),
                ],
                selectedIndex: 0,
                isFocused: true,
                loadingId: loadingId,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('las fotos se piden al tamaño de la miniatura', (tester) async {
      await pumpStrip(tester);
      final images = tester.widgetList<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(images, isNotEmpty);
      // Lo justo para cubrir 192×108 a densidad 2 con fotos de hasta 2,4:1,
      // no los 1920–4096 px de la foto.
      for (final image in images) {
        expect(image.memCacheWidth, 519);
      }
    });

    testWidgets('la que se está abriendo muestra que carga', (tester) async {
      await pumpStrip(tester);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await pumpStrip(tester, loadingId: 'b');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('Inicio en el TV', () {
    testWidgets('entran 4 tarjetas y ninguna desborda', (tester) async {
      useSpanishTranslations();
      await addToWatchlist(['Coco', 'Up']);
      await tester.runAsync(
        () => MovieProgressService.saveProgress(
          contentId: 'w1',
          currentPosition: const Duration(minutes: 30),
          totalDuration: const Duration(minutes: 120),
          movie: MovieItem(contentId: 'w1', name: 'Wall-E'),
        ),
      );
      await pumpHome(tester, onTv: true);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();

      // Clima, Eventos, Seguir viendo e Interesantes a la vez.
      expect(find.byType(HomeContinueCard), findsOneWidget);
      expect(find.byType(HomeWatchlistCard), findsOneWidget);
      expect(find.text('Revisá tu actividad para hoy'), findsOneWidget);
      // Un desborde haría fallar el test (lo reporta Flutter).
      expect(tester.takeException(), isNull);
    });
  });

  group('Eventos en el Inicio', () {
    CalendarEvent event(String id, DateTime start) => CalendarEvent(
      id: id,
      subscriptionId: 'nfl',
      title: 'Partido $id',
      competition: 'nfl',
      startDateTime: start,
    );

    testWidgets('sin eventos para hoy la tarjeta no aparece', (tester) async {
      useSpanishTranslations();
      await pumpHome(tester);
      expect(find.byType(HomeEventsCard), findsNothing);
    });

    testWidgets('con un evento por empezar hoy, aparece', (tester) async {
      useSpanishTranslations();
      final calendar = CalendarProvider(preferences: prefs, startTicker: false);
      addTearDown(calendar.dispose);
      await tester.runAsync(() => subscribeNfl(calendar));
      final now = ArgentinaTime.now();
      final later = now.add(const Duration(minutes: 30));
      // Que siga siendo hoy aunque el test corra cerca de medianoche.
      final start = later.day == now.day ? later : now;
      calendar.debugSetEvents([event('a', start)]);
      await pumpHome(tester, calendar: calendar);
      expect(find.byType(HomeEventsCard), findsOneWidget);
    });
  });

  testWidgets('en el TV, un evento de título largo entra sin desbordar', (
    tester,
  ) async {
    useSpanishTranslations();
    final calendar = CalendarProvider(preferences: prefs, startTicker: false);
    addTearDown(calendar.dispose);
    await tester.runAsync(() => subscribeNfl(calendar));
    final now = ArgentinaTime.now();
    final later = now.add(const Duration(minutes: 30));
    calendar.debugSetEvents([
      CalendarEvent(
        id: 'largo',
        subscriptionId: 'nfl',
        // Dos líneas de título y la competición abajo: el caso más alto.
        title: 'Kansas City Chiefs vs. San Francisco 49ers en vivo',
        competition: 'NFL · Temporada regular',
        startDateTime: later.day == now.day ? later : now,
      ),
    ]);
    await pumpHome(tester, calendar: calendar, onTv: true);
    expect(find.byType(HomeEventsCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('el calendario nota cuando un evento de hoy empieza', () async {
    SharedPreferences.setMockInitialValues({});
    final calendar = CalendarProvider(
      preferences: await AppPreferences.init(),
      startTicker: false,
    );
    addTearDown(calendar.dispose);
    await subscribeNfl(calendar);
    final now = ArgentinaTime.now();
    CalendarEvent at(DateTime start) => CalendarEvent(
      id: 'x',
      subscriptionId: 'nfl',
      title: 'Partido',
      competition: 'nfl',
      startDateTime: start,
    );
    final soon = now.add(const Duration(minutes: 1));
    if (soon.day != now.day) return; // justo a medianoche: no aplica
    calendar.debugSetEvents([at(soon)]);
    final before = calendar.todayStatusKey();
    // El mismo evento, ya empezado.
    calendar.debugSetEvents([at(now.subtract(const Duration(minutes: 1)))]);
    expect(calendar.todayStatusKey(), isNot(before));
  });
}

/// Espera a que el calendario cargue sus suscripciones y deja NFL activa.
Future<void> subscribeNfl(CalendarProvider calendar) async {
  for (var i = 0; i < 100 && calendar.subscriptions.isEmpty; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  final nfl = calendar.subscriptions.firstWhere((s) => s.id == 'nfl');
  if (!nfl.isSubscribed) await calendar.toggleSubscription('nfl');
}
