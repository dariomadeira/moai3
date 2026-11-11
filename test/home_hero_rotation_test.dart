import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/home_hero_rotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

MovieItem movie(int i) =>
    MovieItem(contentId: 'm$i', name: 'Película $i', programType: 'movie');

void main() {
  final movies = [for (var i = 0; i < 4; i++) movie(i)];
  final rotation = HomeHeroRotation.movies;

  Future<int> boot() async {
    rotation.debugReset();
    await rotation.load();
    return rotation.startIndex(movies);
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sin dato empieza por la primera', () async {
    expect(await boot(), 0);
  });

  test('cada arranque empieza por la que sigue a la última vista', () async {
    expect(await boot(), 0);
    expect(await boot(), 1);
    expect(await boot(), 2);
    expect(await boot(), 3);
    expect(await boot(), 0);
  });

  test('si pasó con las flechas, sigue desde la última que vio', () async {
    expect(await boot(), 0);
    await rotation.remember(movies[2]);
    expect(await boot(), 3);
  });

  test('en el mismo arranque no cambia', () async {
    expect(await boot(), 0);
    expect(rotation.startIndex(movies), 0);
  });

  test('si la última ya no está en la lista, la primera', () async {
    SharedPreferences.setMockInitialValues({'home_hero_last_movie': 'otra'});
    expect(await boot(), 0);
  });

  test('la tarjeta grande de la sección arranca con la del Inicio', () async {
    SharedPreferences.setMockInitialValues({'home_hero_last_movie': 'm1'});
    expect(await boot(), 2);
    // Otra lista que también la tiene: arranca ahí.
    final banner = [movie(9), movie(2), movie(7)];
    expect(rotation.chosenIndex(banner), 1);
    // Si no la tiene, la primera.
    expect(rotation.chosenIndex([movie(8)]), 0);
  });

  test('series rota aparte de películas', () async {
    final series = HomeHeroRotation.series;
    await boot();
    series.debugReset();
    await series.load();
    expect(series.startIndex(movies), 0);
    expect(rotation.startIndex(movies), 0);
    await series.remember(movies[3]);
    series.debugReset();
    await series.load();
    expect(series.startIndex(movies), 0);
    rotation.debugReset();
    await rotation.load();
    expect(rotation.startIndex(movies), 1);
  });
}
