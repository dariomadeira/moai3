import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const total = Duration(minutes: 120);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<MovieWatchProgress?> save(Duration at) =>
      MovieProgressService.saveProgress(
        contentId: 'm1',
        currentPosition: at,
        totalDuration: total,
      );

  test('antes de los 3 min no hay progreso', () async {
    expect(await save(const Duration(minutes: 2)), isNull);
    expect(await MovieProgressService.getProgress('m1'), isNull);
  });

  test('de los 3 min a 5 min del final queda en curso para retomar', () async {
    final saved = await save(const Duration(minutes: 40));
    expect(saved?.canResume, isTrue);
    expect(saved?.positionSeconds, 40 * 60);
  });

  test('en los últimos 5 min queda vista', () async {
    final saved = await save(const Duration(minutes: 116));
    expect(saved?.isCompleted, isTrue);
    expect(saved?.canResume, isFalse);
  });

  test('empezar de nuevo y salir antes de 3 min deja el punto viejo', () async {
    await save(const Duration(minutes: 40));
    final saved = await save(const Duration(minutes: 1));
    expect(saved?.positionSeconds, 40 * 60);
    expect(
      (await MovieProgressService.getProgress('m1'))?.positionSeconds,
      40 * 60,
    );
    // Pasados los 3 min, el punto nuevo reemplaza al viejo.
    expect((await save(const Duration(minutes: 5)))?.positionSeconds, 5 * 60);
  });

  test('volver a ver una ya vista unos minutos no le quita "vista"', () async {
    await save(const Duration(minutes: 118));
    final saved = await save(const Duration(minutes: 1));
    expect(saved?.isCompleted, isTrue);
    expect((await MovieProgressService.getProgress('m1'))?.isCompleted, isTrue);
  });

  test('"Seguir viendo": sólo en curso, la última vista primero', () async {
    Future<void> at(String id, int minutes) =>
        MovieProgressService.saveProgress(
          contentId: id,
          currentPosition: Duration(minutes: minutes),
          totalDuration: total,
          movie: MovieItem(contentId: id, name: 'Peli $id'),
        );
    await at('a', 40);
    await Future<void>.delayed(const Duration(seconds: 1));
    await at('b', 20);
    await at('vista', 118);
    await at('apenas', 1);

    final list = await MovieProgressService.inProgress();
    expect(list.map((p) => p.contentId), ['b', 'a']);
    // La película viaja con el progreso.
    expect(list.first.movie?.name, 'Peli b');
  });

  test('marcar como vista aunque esté a la mitad', () async {
    await save(const Duration(minutes: 40));
    final marked = await MovieProgressService.markWatched('m1');
    expect(marked.isCompleted, isTrue);
    expect(await MovieProgressService.inProgress(), isEmpty);
  });

  test('una vista no guarda la película (sólo Seguir viendo la usa)', () async {
    await MovieProgressService.saveProgress(
      contentId: 'v',
      currentPosition: const Duration(minutes: 118),
      totalDuration: total,
      movie: MovieItem(contentId: 'v', name: 'Vista'),
    );
    final saved = await MovieProgressService.getProgress('v');
    expect(saved?.isCompleted, isTrue);
    expect(saved?.movie, isNull);
  });

  test('recuerda hasta maxWatched vistas, olvida las más viejas', () async {
    const max = MovieProgressService.maxWatched;
    final values = <String, Object>{
      for (var i = 0; i < max; i++)
        'movie_progress_v$i':
            '{"contentId":"v$i","positionSeconds":0,"totalDurationSeconds":60,'
            '"isCompleted":true,"lastWatchedAt":${100 + i}}',
    };
    SharedPreferences.setMockInitialValues(values);
    await MovieProgressService.markWatched('nueva');

    expect(await MovieProgressService.getProgress('nueva'), isNotNull);
    // La más vieja (lastWatchedAt 100) se olvidó; la siguiente sigue.
    expect(await MovieProgressService.getProgress('v0'), isNull);
    expect(await MovieProgressService.getProgress('v1'), isNotNull);
  });
}
