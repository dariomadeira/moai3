import 'package:flutter/widgets.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_search_history.dart';
import 'package:moai3/utils/safe_change_notifier.dart';
import 'package:moai3/utils/text_normalize.dart';

/// Pide una página de la búsqueda del servidor; `null` si falló.
typedef MovieSearchFetcher =
    Future<MovieSearchPage?> Function(String query, int page);

/// Estado del panel Buscar de Películas (SPEC-45): búsqueda en el servidor,
/// paginado, respaldo en el catálogo guardado y últimas búsquedas.
class MovieSearchController extends ChangeNotifier with SafeChangeNotifier {
  static const int minQueryLength = 2;

  /// Si tras limpiar quedan menos, se pide la página siguiente sola.
  static const int _fillTarget = 10;

  /// Páginas que se piden de una vez buscando películas entre las series.
  static const int _autoPages = 3;

  final MovieSearchFetcher fetch;

  /// Las películas del catálogo guardado, para cuando el servidor no contesta.
  final List<MovieItem> Function() localMovies;
  final MovieSearchHistory _history;

  MovieSearchController({
    required this.fetch,
    required this.localMovies,
    MovieSearchHistory? history,
  }) : _history = history ?? MovieSearchHistory();

  final TextEditingController queryController = TextEditingController();

  String _query = '';
  List<MovieItem> results = const [];
  bool isLoading = false;
  bool isLoadingMore = false;

  /// Los resultados salen del catálogo guardado: el servidor no contestó.
  bool isOffline = false;

  List<String> history = const [];

  int _page = 0;
  bool _exhausted = true;
  final Set<String> _seen = {};

  /// Sólo cuenta la última búsqueda: una respuesta vieja que llega tarde se
  /// descarta.
  int _generation = 0;

  /// Lo buscado; vacío mientras se muestran las últimas búsquedas.
  String get query => _query;

  bool get showHistory => _query.isEmpty;

  bool get canLoadMore => !_exhausted && !isLoading && !isLoadingMore;

  Future<void> loadHistory() async {
    history = await _history.load();
    safeNotifyListeners();
  }

  Future<void> search(String text) async {
    final query = text.trim();
    final generation = ++_generation;
    _seen.clear();
    results = const [];
    _page = 0;
    isOffline = false;
    isLoadingMore = false;
    if (query.length < minQueryLength) {
      _query = '';
      isLoading = false;
      _exhausted = true;
      safeNotifyListeners();
      return;
    }
    _query = query;
    isLoading = true;
    _exhausted = false;
    safeNotifyListeners();

    await _fill(generation, target: _fillTarget, lastPage: _autoPages);
    if (generation != _generation) return;
    isLoading = false;
    safeNotifyListeners();
  }

  /// Borra el texto y vuelve a las últimas búsquedas.
  void clear() {
    queryController.clear();
    search('');
  }

  /// Agrega la página siguiente abajo (al llegar a la última fila).
  Future<void> loadMore() async {
    if (!canLoadMore) return;
    final generation = _generation;
    isLoadingMore = true;
    safeNotifyListeners();
    await _fill(
      generation,
      target: results.length + 1,
      lastPage: _page + _autoPages,
    );
    if (generation != _generation) return;
    isLoadingMore = false;
    safeNotifyListeners();
  }

  /// Al abrir una película de los resultados: la búsqueda va a Recientes.
  Future<void> rememberQuery() async {
    if (_query.isEmpty) return;
    history = await _history.remember(_query);
    safeNotifyListeners();
  }

  Future<void> _fill(
    int generation, {
    required int target,
    required int lastPage,
  }) async {
    while (!_exhausted && results.length < target && _page < lastPage) {
      final page = _page + 1;
      MovieSearchPage? response;
      try {
        response = await fetch(_query, page);
      } catch (_) {
        response = null;
      }
      if (generation != _generation) return;
      if (response == null) {
        if (page == 1) {
          results = searchLocalMovies(localMovies(), _query);
          isOffline = true;
        }
        _exhausted = true;
        return;
      }
      _page = page;
      final clean = cleanSearchPage(response.items, _query, _seen);
      if (clean.isNotEmpty) results = [...results, ...clean];
      if (response.items.isEmpty ||
          page * MovieSearchPage.pageSize >= response.total) {
        _exhausted = true;
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    queryController.dispose();
    super.dispose();
  }
}

/// Limpia una página del servidor (SPEC-45 §4.3): sólo películas, sin las ya
/// vistas en [seen] (que se actualiza) y, dentro de la página, primero las
/// que tienen todas las palabras buscadas en el título.
List<MovieItem> cleanSearchPage(
  List<MovieItem> items,
  String query,
  Set<String> seen,
) {
  final movies = <MovieItem>[];
  for (final movie in items) {
    if (!movie.isMovie) continue;
    final byTitle = '${normalizeText(movie.name)}|${movie.year ?? ''}';
    final isNew = movie.contentId.isEmpty
        ? seen.add(byTitle)
        : seen.add(movie.contentId) & seen.add(byTitle);
    if (isNew) movies.add(movie);
  }
  return _titleMatchesFirst(movies, query);
}

/// Búsqueda en el catálogo guardado cuando el servidor no contesta: todas las
/// palabras en el título, el alias, los actores o el director.
List<MovieItem> searchLocalMovies(List<MovieItem> movies, String query) {
  final words = _words(query);
  if (words.isEmpty) return const [];
  final seen = <String>{};
  final matches = [
    for (final movie in movies)
      if (movie.isMovie &&
          seen.add(movie.contentId.isEmpty ? movie.name : movie.contentId) &&
          _hasAll(
            normalizeText(
              '${movie.name} ${movie.alias ?? ''} '
              '${movie.actorDisplay ?? ''} ${movie.director ?? ''}',
            ),
            words,
          ))
        movie,
  ];
  return _titleMatchesFirst(matches, query);
}

List<MovieItem> _titleMatchesFirst(List<MovieItem> movies, String query) {
  final words = _words(query);
  bool inTitle(MovieItem m) =>
      _hasAll(normalizeText('${m.name} ${m.alias ?? ''}'), words);
  return [...movies.where(inTitle), ...movies.where((m) => !inTitle(m))];
}

List<String> _words(String query) =>
    normalizeText(query).split(' ').where((w) => w.isNotEmpty).toList();

bool _hasAll(String text, List<String> words) =>
    words.every((w) => text.contains(w));
