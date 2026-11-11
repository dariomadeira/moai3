import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/home_hero_rotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

MovieItem movie(int i) =>
    MovieItem(contentId: 'm$i', name: 'Película $i', programType: 'movie');

void main() {
  final movies = [for (var i = 0; i < 4; i++) movie(i)];

  Future<int> boot() async {
    HomeHeroRotation.debugReset();
    await HomeHeroRotation.load();
    return HomeHeroRotation.startIndex(movies);
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
    await HomeHeroRotation.remember(movies[2]);
    expect(await boot(), 3);
  });

  test('en el mismo arranque no cambia', () async {
    expect(await boot(), 0);
    expect(HomeHeroRotation.startIndex(movies), 0);
  });

  test('si la última ya no está en la lista, la primera', () async {
    SharedPreferences.setMockInitialValues({'home_hero_last_movie': 'otra'});
    expect(await boot(), 0);
  });
}
