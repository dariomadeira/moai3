import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/areas/home_movies_area.dart';
import 'package:moai3/state/movie_provider.dart';

void main() {
  group('HomeMoviesArea Widget Tests (SPEC-38)', () {
    testWidgets('renders HomeMoviesArea header and movies list', (WidgetTester tester) async {
      final movieProvider = MovieProvider();

      Future<String> mockFetcher(String url) async {
        return json.encode({
          'metas': [
            {
              'id': 'tt0137523',
              'name': 'El Club de la Pelea',
              'description': 'Sinopsis...',
              'poster': 'https://image.com/poster.jpg',
              'year': '1999',
              'imdbRating': 8.8,
            }
          ]
        });
      }

      await movieProvider.loadPopularMovies(customFetcher: mockFetcher);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: movieProvider,
              child: HomeMoviesArea(
                onExitLeft: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('El Club de la Pelea'), findsOneWidget);
    });
  });
}
