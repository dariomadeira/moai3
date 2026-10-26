import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_library.dart';
import 'package:moai3/services/movie_progress_service.dart';
import 'package:moai3/services/movie_watchlist_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const total = Duration(minutes: 120);
  final coco = MovieItem(contentId: 'c', name: 'Coco');
  final watchlist = MovieWatchlistService.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    watchlist.resetForTest();
  });

  group('recordProgress', () {
    test('antes de los 3 min sigue en Interesantes', () async {
      await watchlist.toggle(coco);
      await MovieLibrary.recordProgress(
        movie: coco,
        position: const Duration(minutes: 2),
        total: total,
      );
      expect(watchlist.contains('c'), isTrue);
    });

    test('pasados los 3 min pasa a Seguir viendo', () async {
      await watchlist.toggle(coco);
      final saved = await MovieLibrary.recordProgress(
        movie: coco,
        position: const Duration(minutes: 30),
        total: total,
      );
      expect(saved?.canResume, isTrue);
      expect(watchlist.contains('c'), isFalse);
      final entries = await MovieLibrary.continueWatching();
      expect(entries.single.movie.name, 'Coco');
      expect(entries.single.watched, closeTo(0.25, 0.001));
    });

    test(
      'una ya vista y vuelta a marcar no sale por abrirla un rato',
      () async {
        await MovieProgressService.markWatched('c');
        await watchlist.toggle(coco);
        await MovieLibrary.recordProgress(
          movie: coco,
          position: const Duration(minutes: 1),
          total: total,
        );
        expect(watchlist.contains('c'), isTrue);
      },
    );
  });

  group('continueWatching', () {
    test('busca en el catálogo los progresos sin película', () async {
      // Un progreso viejo: sin la película guardada.
      await MovieProgressService.saveProgress(
        contentId: 'c',
        currentPosition: const Duration(minutes: 30),
        totalDuration: total,
      );
      expect(await MovieLibrary.continueWatching(), isEmpty);
      final entries = await MovieLibrary.continueWatching(
        lookup: (id) => id == 'c' ? coco : null,
      );
      expect(entries.single.movie.name, 'Coco');
    });

    test('limpia Interesantes de las que estaban en las dos', () async {
      await watchlist.toggle(coco);
      await MovieProgressService.saveProgress(
        contentId: 'c',
        currentPosition: const Duration(minutes: 30),
        totalDuration: total,
        movie: coco,
      );
      await MovieLibrary.continueWatching();
      expect(watchlist.contains('c'), isFalse);
    });
  });

  test('markWatched la saca de Seguir viendo y de Interesantes', () async {
    await watchlist.toggle(coco);
    await MovieProgressService.saveProgress(
      contentId: 'c',
      currentPosition: const Duration(minutes: 30),
      totalDuration: total,
      movie: coco,
    );
    await MovieLibrary.markWatched([coco]);
    expect(await MovieLibrary.continueWatching(), isEmpty);
    expect(watchlist.contains('c'), isFalse);
    expect((await MovieProgressService.getProgress('c'))?.isCompleted, isTrue);
  });
}
