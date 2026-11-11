import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moai3/features/movies/screens/movie_detail_screen.dart';
import 'package:moai3/features/movies/widgets/tv_movie_genre_chip.dart';
import 'package:moai3/features/movies/widgets/tv_movie_hero_card.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/movie_watchlist_service.dart';
import 'package:moai3/services/movie_progress_service.dart';
import 'package:moai3/services/movie_recommendations_api.dart';
import 'package:moai3/state/movie_recommendations_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/widgets/buttons/moai_pill_button.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';
import 'helpers/spanish_translations.dart';

class _VotesApi extends MovieRecommendationsApi {
  @override
  Future<List<Map<String, dynamic>>> fetch(List<String> friendIds) async =>
      const [];

  @override
  Future<void> recommend(String deviceId, MovieItem movie) async {}

  @override
  Future<void> remove(String deviceId, String contentId) async {}
}

void main() {
  group('MovieItem Content Type & Helpers Tests', () {
    test(
      'tráiler del catálogo: por tipo o por la palabra, con tilde o sin',
      () {
        MovieItem item(String name, [String? type]) =>
            MovieItem(contentId: name, name: name, programType: type);

        expect(item('Weapons', 'trailer').isCatalogTrailer, isTrue);
        expect(item('(Tráiler)Weapons').isCatalogTrailer, isTrue);
        expect(item('Superman - TRAILER').isCatalogTrailer, isTrue);
        expect(item('Coco', 'movie').isCatalogTrailer, isFalse);
        expect(item('Trailers de verano').isCatalogTrailer, isFalse);
        // Ninguno es un adelanto del Inicio (esos traen video de YouTube).
        expect(item('Weapons', 'trailer').isTrailer, isFalse);
      },
    );

    test('displayName: "Adelanto - …" sólo en los adelantos del Inicio', () {
      useSpanishTranslations();
      expect(
        MovieItem(
          contentId: 'tmdb_1',
          name: 'Weapons',
          youtubeTrailerKey: 'abc',
        ).displayName,
        'Adelanto - Weapons',
      );
      expect(
        MovieItem(
          contentId: '1',
          name: 'Weapons',
          programType: 'movie',
        ).displayName,
        'Weapons',
      );
    });

    test('elenco: un espacio después de cada coma', () {
      String? cast(String? raw) =>
          MovieItem(contentId: '1', name: 'X', actorDisplay: raw).formattedCast;

      expect(
        cast('Sam Worthington,Zoe Saldana,Sigourney Weaver'),
        'Sam Worthington, Zoe Saldana, Sigourney Weaver',
      );
      expect(cast('Uno ,  Dos,'), 'Uno, Dos');
      expect(cast(' , '), isNull);
      expect(cast(null), isNull);
    });

    test('director: un espacio después de cada coma, como el elenco', () {
      String? director(String? raw) =>
          MovieItem(contentId: '1', name: 'X', director: raw).formattedDirector;

      expect(
        director('Tom Verica,Sheree Folkson,Alrick Riley'),
        'Tom Verica, Sheree Folkson, Alrick Riley',
      );
      expect(director('James Cameron'), 'James Cameron');
      expect(director(' , '), isNull);
      expect(director(null), isNull);
    });

    test('el video del adelanto se guarda y se relee', () {
      final movie = MovieItem.fromJson(
        MovieItem(
          contentId: 'tmdb_1',
          name: 'Weapons',
          youtubeTrailerKey: 'abc',
        ).toJson(),
      );
      expect(movie.youtubeTrailerKey, 'abc');
      expect(movie.isTrailer, isTrue);
      expect(
        MovieItem(contentId: '1', name: 'Coco').toJson(),
        isNot(contains('youtubeTrailerKey')),
      );
    });

    test('Identifica correctamente película, serie y trailer', () {
      useSpanishTranslations();
      final movie = MovieItem(
        contentId: '1',
        name: 'El Secreto de sus Ojos',
        programType: 'movie',
        duration: '02:09:00',
        score: '8.2',
        year: '2009',
        tags: 'Crime,Drama,Mystery',
      );
      expect(movie.isMovie, isTrue);
      expect(movie.isSeries, isFalse);
      expect(movie.isTrailer, isFalse);
      expect(movie.formattedDuration, '2h 9m');
      expect(movie.formattedScore, '8.2');
      expect(movie.formattedYear, '2009');
      expect(movie.genreList, ['Crimen', 'Drama', 'Misterio']);

      final series1 = MovieItem(
        contentId: '2',
        name: 'Breaking Bad Temporada 1',
        programType: 'series',
      );
      expect(series1.isSeries, isTrue);
      expect(series1.isMovie, isFalse);

      final series2 = MovieItem(contentId: '3', name: 'Los Simuladores T2');
      expect(series2.isSeries, isTrue);
      expect(series2.isMovie, isFalse);

      final trailer = MovieItem(
        contentId: '4',
        name: 'Inception Trailer Oficial',
        programType: 'trailer',
      );
      expect(trailer.isCatalogTrailer, isTrue);
      expect(trailer.isMovie, isFalse);

      final tenzing = MovieItem(
        contentId: '5',
        name: 'Tenzing',
        tags: 'Adventure, Biography, Drama, History, Thriller',
      );
      expect(tenzing.genreList, [
        'Aventura',
        'Biografía',
        'Drama',
        'Historia',
        'Suspenso',
      ]);
    });

    test(
      'el año guardado: sólo 4 dígitos, y se descarta la fecha de subida vieja',
      () {
        // Lo que guardaba la versión anterior: la fecha de `shelveTime`.
        final old = MovieItem.fromJson({
          'contentId': '1',
          'name': 'Rocky',
          'year': '2025-08-10',
        });
        expect(old.formattedYear, isNull);

        final fromRelease = MovieItem.fromJson({
          'contentId': '2',
          'name': 'Rocky',
          'releaseTime': '1976-11-21',
        });
        expect(fromRelease.formattedYear, '1976');
        // Al guardar queda sólo el año y al volver a leerlo se conserva.
        expect(fromRelease.toJson()['year'], '1976');
        expect(MovieItem.fromJson(fromRelease.toJson()).formattedYear, '1976');
      },
    );

    test(
      'Parsea backdrops múltiples de posterList y genera stageImages distintas al backdrop principal',
      () {
        final json = {
          'contentId': '777',
          'name': 'Tron: Ares',
          'posterList': [
            {
              'fileType': 'poster',
              'fileUrl': 'https://example.com/poster_tron.jpg',
              'size': '1920*1080',
            },
            {
              'fileType': 'icon',
              'fileUrl': 'https://example.com/icon_tron.jpg',
              'size': '262*370',
            },
            {
              'fileType': 'stage',
              'fileUrl': 'https://example.com/stage1.jpg',
              'size': '1920*1080',
            },
            {
              'fileType': 'stage',
              'fileUrl': 'https://example.com/stage2.jpg',
              'size': '1920*1080',
            },
            {
              'fileType': 'stage',
              'fileUrl': 'https://example.com/thumb.jpg',
              'size': '100*100',
            },
          ],
        };

        final movie = MovieItem.fromJson(json);
        expect(movie.effectiveBackdrop, 'https://example.com/poster_tron.jpg');
        expect(movie.backdrops.length, 4);
        expect(
          movie.backdrops,
          contains('https://example.com/poster_tron.jpg'),
        );
        expect(movie.backdrops, contains('https://example.com/stage1.jpg'));
        expect(movie.backdrops, contains('https://example.com/stage2.jpg'));
        expect(movie.backdrops, contains('https://example.com/thumb.jpg'));

        expect(movie.ambientBackdrop, 'https://example.com/poster_tron.jpg');
        // stageImages excluye estrictamente el fondo ambiental para no duplicar jamás en el carrusel
        expect(movie.stageImages, [
          'https://example.com/stage1.jpg',
          'https://example.com/stage2.jpg',
          'https://example.com/thumb.jpg',
        ]);
        expect(movie.stageImages, isNot(contains(movie.ambientBackdrop)));

        // Película con una sola imagen (como Firewall): el fondo ambiental SIEMPRE carga
        final singleImageMovie = MovieItem(
          contentId: '888',
          name: 'Firewall',
          backdrop: 'https://example.com/firewall.jpg',
        );
        expect(
          singleImageMovie.ambientBackdrop,
          'https://example.com/firewall.jpg',
        );
        expect(singleImageMovie.stageImages, [
          'https://example.com/firewall.jpg',
        ]);
      },
    );
  });

  group('MovieDetailScreen Widget Tests', () {
    late AppPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      MovieWatchlistService.instance.resetForTest();
      prefs = await AppPreferences.init();
    });

    Future<void> pumpDetail(
      WidgetTester tester,
      MovieItem movie, {
      Brightness brightness = Brightness.dark,
      Future<ResolvedPlayStream?> Function(MovieItem)? resolveStream,
      Future<String?> Function(MovieItem)? resolveYear,
      Future<bool> Function(String videoId)? openTrailer,
      MovieRecommendationsProvider? recommendations,
    }) async {
      useSpanishTranslations();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => TvSettingsProvider(prefs)),
              if (recommendations != null)
                ChangeNotifierProvider.value(value: recommendations),
            ],
            child: MovieDetailScreen(
              movie: movie,
              resolveStream: resolveStream ?? (_) async => null,
              resolveYear: resolveYear,
              openTrailer: openTrailer ?? (_) async => true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// El color del número de una etiqueta (la nota va en la estrella y el
    /// número; la etiqueta es de cristal como las demás).
    Color pillColor(WidgetTester tester, String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;

    String? focused() => FocusManager.instance.primaryFocus?.debugLabel;

    group('votar', () {
      final movie = MovieItem(contentId: 'm1', name: 'Coco');

      testWidgets('sin amigos no hay botones', (tester) async {
        await pumpDetail(tester, movie);

        expect(find.byIcon(MoaiIcons.vodRecommend), findsNothing);
        expect(find.byIcon(MoaiIcons.vodNotRecommend), findsNothing);
      });

      testWidgets('se elige 👍 o 👎 desde Marcar y se puede cambiar', (
        tester,
      ) async {
        final votes = MovieRecommendationsProvider(
          api: _VotesApi(),
          isWatched: (_) async => false,
        );
        votes.setFriends(deviceId: 'yo', friends: const {'ana': 'Ana'});
        await tester.runAsync(votes.ensureLoaded);
        await pumpDetail(tester, movie, recommendations: votes);

        Future<void> press(LogicalKeyboardKey key) async {
          await tester.sendKeyEvent(key);
          await tester.pump();
          await tester.runAsync(() => Future<void>.delayed(Duration.zero));
          await tester.pump();
        }

        await press(LogicalKeyboardKey.arrowDown);
        expect(focused(), 'movie_detail_watchlist');
        await press(LogicalKeyboardKey.arrowRight);
        expect(focused(), 'movie_detail_up');

        await press(LogicalKeyboardKey.select);
        expect(votes.voteOf('m1'), MovieVote.up);

        await press(LogicalKeyboardKey.arrowRight);
        expect(focused(), 'movie_detail_down');
        await press(LogicalKeyboardKey.select);
        expect(votes.voteOf('m1'), MovieVote.down);

        await press(LogicalKeyboardKey.select);
        expect(votes.voteOf('m1'), isNull);

        await tester.pump(const Duration(seconds: 5));
      });
    });

    testWidgets(
      'Muestra información detallada, botón back, hero card y score pill',
      (tester) async {
        final movie = MovieItem(
          contentId: '100',
          name: 'Interstellar',
          alias: 'Interstellar Original',
          score: '8.7',
          year: '2014',
          duration: '02:49:00',
          tags: 'Adventure,Drama,Sci-Fi',
          director: 'Christopher Nolan',
          actorDisplay: 'Matthew McConaughey, Anne Hathaway',
          description:
              'Un grupo de exploradores viaja a través de un agujero de gusano.',
        );
        await pumpDetail(tester, movie);

        expect(find.byType(TvBackPill), findsOneWidget);
        expect(find.text('Interstellar'), findsAtLeastNWidgets(1));
        expect(find.text('Interstellar Original'), findsOneWidget);

        // Puntaje > 7.0: dorado.
        expect(find.text('8.7'), findsOneWidget);
        expect(pillColor(tester, '8.7'), const Color(0xFFFBBF24));

        // La calidad no se inventa: recién se sabe al reproducir.
        expect(find.text('1080P HD'), findsNothing);

        expect(find.text('Christopher Nolan'), findsOneWidget);
        expect(find.text('Matthew McConaughey, Anne Hathaway'), findsOneWidget);

        expect(find.byType(TvMovieGenreChip), findsNWidgets(3));
        expect(find.text('Ciencia ficción'), findsOneWidget);
        expect(find.text('Aventura'), findsOneWidget);
        expect(find.text('Drama'), findsOneWidget);

        // Marcar como interesante es un botón aparte; Reproducir vive en la Hero.
        expect(find.byType(TvFocusButton), findsOneWidget);
        expect(find.text('Marcar'), findsOneWidget);
        expect(find.byType(TvMovieHeroCard), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(TvMovieHeroCard),
            matching: find.text('Reproducir'),
          ),
          findsOneWidget,
        );
        expect(find.text('Reproducir'), findsOneWidget);
        // El mismo botón que la tarjeta grande del Inicio: vidrio, y con la
        // Hero enfocada (arranca así), el foco de la app.
        final play = tester.widget<MoaiPillButton>(
          find.ancestor(
            of: find.text('Reproducir'),
            matching: find.byType(MoaiPillButton),
          ),
        );
        expect(play.kind, MoaiPillButtonKind.glass);
        expect(play.selected, isTrue);
        expect(play.loading, isFalse);

        // Con foco en Marcar, el botón queda de vidrio sin foco.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(
          tester.widget<MoaiPillButton>(find.byType(MoaiPillButton)).selected,
          isFalse,
        );
      },
    );

    testWidgets(
      'el puntaje es una etiqueta de cristal como las demás y la nota '
      'colorea la estrella y el número',
      (tester) async {
        Future<void> expectScore(
          String score,
          Color color, {
          Brightness brightness = Brightness.light,
        }) async {
          await pumpDetail(
            tester,
            MovieItem(contentId: score, name: 'Nota', score: score),
            brightness: brightness,
          );
          final pill = find.ancestor(
            of: find.text(score),
            matching: find.byType(TvMetaPill),
          );
          expect(tester.widget<Text>(find.text(score)).style!.color, color);
          expect(
            tester
                .widget<Icon>(
                  find.descendant(of: pill, matching: find.byType(Icon)),
                )
                .color,
            color,
          );
        }

        await expectScore('8.1', const Color(0xFFD97706));
        await expectScore('6.5', const Color(0xFF64748B));
        await expectScore('4.2', const Color(0xFFDC2626));
        // En el oscuro, los mismos tonos aclarados (sobre el ahumado).
        const dark = Brightness.dark;
        await expectScore('8.1', const Color(0xFFFBBF24), brightness: dark);
        await expectScore('6.5', const Color(0xFFCBD5E1), brightness: dark);
        await expectScore('4.2', const Color(0xFFF87171), brightness: dark);
      },
    );

    testWidgets('oculta el título original si es igual al nombre', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        MovieItem(contentId: '104', name: 'Coco', alias: '  coco '),
      );
      expect(find.text('  coco '), findsNothing);
    });

    testWidgets(
      'adelanto: título "Adelanto - …", sin Interesantes, progreso ni duración',
      (tester) async {
        // Aunque hubiera progreso guardado, un tráiler no lo usa.
        await MovieProgressService.saveProgress(
          contentId: 't1',
          currentPosition: const Duration(minutes: 30),
          totalDuration: const Duration(minutes: 120),
        );
        await pumpDetail(
          tester,
          MovieItem(
            contentId: 't1',
            name: 'Weapons',
            alias: 'Weapons',
            duration: '02:08:00',
            youtubeTrailerKey: 'abc',
          ),
        );

        expect(find.text('Adelanto - Weapons'), findsOneWidget);
        // La pestaña lateral dice "Adelanto", no "Película".
        expect(find.text('Adelanto'), findsOneWidget);
        expect(find.text('Película'), findsNothing);
        // El alias es igual al nombre: no se repite.
        expect(find.text('Weapons'), findsNothing);
        expect(find.text('Marcar'), findsNothing);
        expect(find.byType(TvFocusButton), findsNothing);
        expect(find.text('2h 8m'), findsNothing);
        expect(find.text('Reproducir'), findsOneWidget);
        expect(find.text('Reanudar'), findsNothing);
        expect(find.text('25% visto'), findsNothing);

        // ↓ desde la Hero no tiene adónde ir.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(focused(), 'movie_detail_hero');
      },
    );

    testWidgets('adelanto: Reproducir abre YouTube con su video', (
      tester,
    ) async {
      final opened = <String>[];
      var resolved = 0;
      await pumpDetail(
        tester,
        MovieItem(
          contentId: 'tmdb_1',
          name: 'Weapons',
          youtubeTrailerKey: 'abc',
        ),
        openTrailer: (id) async {
          opened.add(id);
          return true;
        },
        resolveStream: (_) async {
          resolved++;
          return null;
        },
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(opened, ['abc']);
      // No pasa por el portal.
      expect(resolved, 0);
      expect(find.text('No se pudo abrir YouTube.'), findsNothing);
    });

    testWidgets('adelanto: si YouTube no abre, lo avisa', (tester) async {
      await pumpDetail(
        tester,
        MovieItem(
          contentId: 'tmdb_1',
          name: 'Weapons',
          youtubeTrailerKey: 'abc',
        ),
        openTrailer: (_) async => false,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('No se pudo abrir YouTube.'), findsOneWidget);
      // El aviso se va solo.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('sin sinopsis muestra el texto de reemplazo', (tester) async {
      await pumpDetail(tester, MovieItem(contentId: '105', name: 'Muda'));
      expect(find.text('Sin sinopsis disponible.'), findsOneWidget);
    });

    testWidgets(
      'con progreso: siempre "Reproducir" y al tocarlo pregunta cómo verla',
      (tester) async {
        await MovieProgressService.saveProgress(
          contentId: '106',
          currentPosition: const Duration(minutes: 30),
          totalDuration: const Duration(minutes: 120),
        );
        var resolved = 0;
        await pumpDetail(
          tester,
          MovieItem(contentId: '106', name: 'A medias'),
          resolveStream: (_) async {
            resolved++;
            return null;
          },
        );

        expect(find.text('Reproducir'), findsOneWidget);
        expect(find.text('Reanudar'), findsNothing);
        expect(find.text('25% visto'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('¿Cómo querés verla?'), findsOneWidget);
        expect(find.text('Te quedaste en 30:00.'), findsOneWidget);
        expect(find.text('Desde el principio'), findsOneWidget);

        // Atrás cancela: no se pide el video.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('¿Cómo querés verla?'), findsNothing);
        expect(resolved, 0);
      },
    );

    testWidgets('elegir "Desde el principio" pide el video', (tester) async {
      await MovieProgressService.saveProgress(
        contentId: '116',
        currentPosition: const Duration(minutes: 30),
        totalDuration: const Duration(minutes: 120),
      );
      var resolved = 0;
      await pumpDetail(
        tester,
        MovieItem(contentId: '116', name: 'Otra vez'),
        resolveStream: (_) async {
          resolved++;
          return null;
        },
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desde el principio'));
      await tester.pumpAndSettle();
      expect(resolved, 1);
    });

    testWidgets('sin progreso, Reproducir no pregunta', (tester) async {
      var resolved = 0;
      await pumpDetail(
        tester,
        MovieItem(contentId: '117', name: 'Nueva'),
        resolveStream: (_) async {
          resolved++;
          return null;
        },
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('¿Cómo querés verla?'), findsNothing);
      expect(resolved, 1);
    });

    testWidgets('terminada muestra Vista', (tester) async {
      await MovieProgressService.saveProgress(
        contentId: '107',
        currentPosition: const Duration(minutes: 118),
        totalDuration: const Duration(minutes: 120),
      );
      await pumpDetail(tester, MovieItem(contentId: '107', name: 'Terminada'));

      expect(
        find.ancestor(
          of: find.text('Vista'),
          matching: find.byType(TvMetaPill),
        ),
        findsOneWidget,
      );
      expect(find.text('Reproducir'), findsOneWidget);
    });

    testWidgets('Marcar como interesante se guarda y se recuerda al volver', (
      tester,
    ) async {
      final movie = MovieItem(contentId: '108', name: 'Querida');
      await pumpDetail(tester, movie);

      await tester.tap(find.text('Marcar'));
      await tester.pumpAndSettle();
      expect(find.text('Desmarcar'), findsOneWidget);
      expect(MovieWatchlistService.instance.contains('108'), isTrue);

      // Pantalla nueva: arranca marcada.
      await tester.pumpWidget(const SizedBox());
      await pumpDetail(tester, movie);
      expect(find.text('Desmarcar'), findsOneWidget);

      await tester.tap(find.text('Desmarcar'));
      await tester.pumpAndSettle();
      expect(find.text('Marcar'), findsOneWidget);
      expect(MovieWatchlistService.instance.contains('108'), isFalse);
    });

    testWidgets(
      'OK con el control en Marcar como interesante la agrega y queda',
      (tester) async {
        await pumpDetail(tester, MovieItem(contentId: '115', name: 'Control'));

        // Hero → ↓ al botón y un OK (apretar y soltar), como con el control.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(find.text('Desmarcar'), findsOneWidget);
        expect(MovieWatchlistService.instance.contains('115'), isTrue);
      },
    );

    testWidgets(
      'foco: arranca en la Hero, ↓ va a Marcar como interesante y ← al back',
      (tester) async {
        await pumpDetail(
          tester,
          MovieItem(contentId: '109', name: 'Foco', description: 'Corta.'),
        );
        expect(focused(), 'movie_detail_hero');

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(focused(), 'movie_detail_watchlist');

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(focused(), 'movie_detail_hero');

        // ← va directo al back.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(focused(), 'movie_detail_back');
      },
    );

    /// El texto de la sinopsis (no el rótulo "Sinopsis").
    Text synopsis(WidgetTester tester, String start) =>
        tester.widget<Text>(find.textContaining(start));

    testWidgets('sinopsis corta: letra de 12 y entera', (tester) async {
      await pumpDetail(
        tester,
        MovieItem(contentId: '112', name: 'Corta', description: 'Una corta.'),
      );
      expect(synopsis(tester, 'Una corta').style!.fontSize, 12);
      // Sin scroll propio (el único es el del acordeón de la pantalla).
      expect(
        find.ancestor(
          of: find.textContaining('Una'),
          matching: find.byType(Scrollable),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sinopsis larga: sin foco ni scroll, achica la letra y entra', (
      tester,
    ) async {
      // Entra con una letra más chica que 12.
      final medium = List.filled(260, 'Una historia larga.').join(' ');
      await pumpDetail(
        tester,
        MovieItem(contentId: '110', name: 'Larga', description: medium),
      );
      final size = synopsis(tester, 'Una historia').style!.fontSize!;
      expect(size, lessThan(12));
      expect(size, greaterThanOrEqualTo(10));
      // Sin scroll propio (el único es el del acordeón de la pantalla).
      expect(
        find.ancestor(
          of: find.textContaining('Una'),
          matching: find.byType(Scrollable),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      // ← desde la Hero va directo al back: la sinopsis no se enfoca.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(focused(), 'movie_detail_back');

      // Ni con la más chica entra: se corta con "…" sin desbordar.
      final huge = List.filled(500, 'Una historia larguísima.').join(' ');
      await pumpDetail(
        tester,
        MovieItem(contentId: '113', name: 'Enorme', description: huge),
      );
      final text = synopsis(tester, 'Una historia');
      expect(text.style!.fontSize, 10);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Reproducir muestra Cargando y avisa si no hay stream', (
      tester,
    ) async {
      final pending = Completer<ResolvedPlayStream?>();
      await pumpDetail(
        tester,
        MovieItem(contentId: '111', name: 'Sin stream'),
        resolveStream: (_) => pending.future,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('Cargando...'), findsOneWidget);
      expect(
        tester.widget<MoaiPillButton>(find.byType(MoaiPillButton)).loading,
        isTrue,
      );

      pending.complete(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('No se pudo conectar con el servidor de streaming.'),
        findsOneWidget,
      );
      expect(find.text('Cargando...'), findsNothing);
      expect(find.text('Reproducir'), findsOneWidget);
    });

    testWidgets('si reproducir falla no muestra el error técnico', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        MovieItem(contentId: '112', name: 'Rota'),
        resolveStream: (_) async => throw Exception('SocketException: boom'),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No se pudo iniciar la reproducción.'), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
    });

    testWidgets(
      'con una sola imagen también muestra el fondo ambiental difuminado',
      (tester) async {
        await pumpDetail(
          tester,
          MovieItem(
            contentId: '113',
            name: 'Una foto',
            backdrop: 'https://example.com/a.jpg',
          ),
        );
        expect(find.byType(ShaderMask), findsWidgets);

        await pumpDetail(
          tester,
          MovieItem(
            contentId: '114',
            name: 'Dos fotos',
            backdrop: 'https://example.com/a.jpg',
            backdrops: const ['https://example.com/b.jpg'],
          ),
        );
        expect(find.byType(ShaderMask), findsWidgets);
      },
    );

    testWidgets(
      'resuelve el año de estreno perezosamente si el catálogo no lo trae',
      (tester) async {
        final rocky = MovieItem(
          contentId: '15406',
          name: 'Rocky',
          score: '8.1',
        );

        await pumpDetail(tester, rocky, resolveYear: (_) async => '1976');

        expect(find.text('1976'), findsOneWidget);
      },
    );
  });
}
