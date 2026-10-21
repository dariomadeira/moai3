import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moai3/features/movies/screens/movie_detail_screen.dart';
import 'package:moai3/features/movies/widgets/tv_movie_genre_chip.dart';
import 'package:moai3/features/movies/widgets/tv_movie_hero_card.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';

void main() {
  group('MovieItem Content Type & Helpers Tests', () {
    test('Identifica correctamente película, serie y trailer', () {
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
      expect(trailer.isTrailer, isTrue);
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
    testWidgets(
      'Muestra información detallada, botón back, hero card, calidad y score pill',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await AppPreferences.init();
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

        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider(
              create: (_) => TvSettingsProvider(prefs),
              child: MovieDetailScreen(movie: movie),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Debe mostrar el TvBackPill
        expect(find.byType(TvBackPill), findsOneWidget);

        // Debe mostrar el título
        expect(find.text('Interstellar'), findsAtLeastNWidgets(1));

        // Debe mostrar la puntuación en un TvMetaPill con color amarillo (> 7.0)
        expect(find.text('8.7'), findsOneWidget);
        final scorePill = tester.widget<TvMetaPill>(
          find.ancestor(
            of: find.text('8.7'),
            matching: find.byType(TvMetaPill),
          ),
        );
        expect(scorePill.foreground, const Color(0xFFFBBF24));

        // Debe mostrar el tag de calidad 1080P HD
        expect(find.text('1080P HD'), findsOneWidget);

        // Debe mostrar el director y elenco
        expect(find.text('Christopher Nolan'), findsOneWidget);
        expect(find.text('Matthew McConaughey, Anne Hathaway'), findsOneWidget);

        // Debe mostrar los chips de género traducidos al castellano
        expect(find.byType(TvMovieGenreChip), findsNWidgets(3));
        expect(find.text('Ciencia ficción'), findsOneWidget);
        expect(find.text('Aventura'), findsOneWidget);
        expect(find.text('Drama'), findsOneWidget);

        // Debe mostrar el botón de Favorito (Reproducir ahora se acciona desde HeroCard)
        expect(find.byType(TvFocusButton), findsOneWidget);
        expect(find.text('Favorito'), findsOneWidget);
        expect(find.text('Reproducir'), findsNothing);

        // Debe mostrar la tarjeta Hero alineada arriba
        expect(find.byType(TvMovieHeroCard), findsOneWidget);
      },
    );

    testWidgets(
      'Score entre 5.0 y 7.0 usa color plata/gris y menor a 5.0 usa rojo',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await AppPreferences.init();

        final movieSilver = MovieItem(
          contentId: '101',
          name: 'Pelicula Media',
          score: '6.5',
        );

        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider(
              create: (_) => TvSettingsProvider(prefs),
              child: MovieDetailScreen(movie: movieSilver),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final silverPill = tester.widget<TvMetaPill>(
          find.ancestor(
            of: find.text('6.5'),
            matching: find.byType(TvMetaPill),
          ),
        );
        expect(silverPill.foreground, const Color(0xFFE2E8F0));

        final movieRed = MovieItem(
          contentId: '102',
          name: 'Pelicula Baja',
          score: '4.2',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider(
              create: (_) => TvSettingsProvider(prefs),
              child: MovieDetailScreen(movie: movieRed),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final redPill = tester.widget<TvMetaPill>(
          find.ancestor(
            of: find.text('4.2'),
            matching: find.byType(TvMetaPill),
          ),
        );
        expect(redPill.foreground, const Color(0xFFF87171));
      },
    );
  });
}
