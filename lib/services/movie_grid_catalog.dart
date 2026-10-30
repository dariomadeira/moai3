import 'package:moai3/models/movie_models.dart';

/// Arma las categorías de la grilla de Películas sin películas repetidas
/// (SPEC-44 §3.2). Funciones puras: no salen a la red.
///
/// El catálogo trae 10 películas por categoría y muchas aparecen en varias
/// (una película de acción y comedia está en las dos). Recorriendo en orden,
/// cada categoría se queda con las que no aparecieron antes y completa con las
/// siguientes de su lista completa del servidor ([extras], `getShelveData`).
///
/// Las categorías del servidor ([withShowAll]) llevan además la tarjeta "Ver
/// todas" (SPEC-44 §3.3): ocupa el último casillero, así que muestran 9
/// películas + la tarjeta y las filas siguen completas.
abstract final class MovieGridCatalog {
  /// Casilleros por categoría: dos filas de 5.
  static const int perCategory = 10;

  /// Las categorías se recortan a múltiplos de esto: filas completas.
  static const int rowLength = 5;

  /// `columnId` de la fila "Mejor puntuadas": local, no es del servidor (la
  /// de TMDb usa 88888).
  static const int topRatedColumnId = 77777;

  /// Fila "Mejor puntuadas" (SPEC-44 §3.4): las películas de [movies] con
  /// más de 7 ([MovieItem.isWellRated]), sin repetir, de mayor a menor
  /// puntaje (a igual puntaje, en el orden del catálogo). `null` si no hay
  /// ninguna. [build] se queda con las que no aparecieron antes.
  static CategoryColumn? topRated(
    List<MovieItem> movies, {
    required String name,
  }) {
    final keys = <String>{};
    final rated = [
      for (final movie in movies)
        if (movie.isMovie && movie.isWellRated && keys.add(keyOf(movie))) movie,
    ];
    if (rated.isEmpty) return null;
    double score(MovieItem m) => double.parse(m.score!.trim());
    final order = {for (var i = 0; i < rated.length; i++) rated[i]: i};
    rated.sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      return byScore != 0 ? byScore : order[a]!.compareTo(order[b]!);
    });
    return CategoryColumn(
      columnId: topRatedColumnId,
      columnName: name,
      movies: rated,
    );
  }

  /// Identidad de una película para comparar entre categorías.
  static String keyOf(MovieItem movie) => movie.contentId.isNotEmpty
      ? movie.contentId
      : '${movie.name}|${movie.poster}';

  /// Películas que busca mostrar la categoría [columnId]: un casillero menos
  /// si lleva "Ver todas".
  static int targetFor(
    int columnId, {
    Set<int> withShowAll = const {},
    int perCategory = perCategory,
  }) => withShowAll.contains(columnId) ? perCategory - 1 : perCategory;

  /// Categorías que perderían alguna película por repetida o que traen menos
  /// de las que buscan mostrar: son las que conviene completar con [extras].
  /// Sólo las de [fetchable] (las del servidor; no la fila de TMDb).
  static Set<int> columnsNeedingMore(
    List<CategoryColumn> categories, {
    required Set<int> fetchable,
    Set<int> withShowAll = const {},
    int perCategory = perCategory,
  }) {
    final seen = <String>{};
    final needing = <int>{};
    for (final category in categories) {
      final target = targetFor(
        category.columnId,
        withShowAll: withShowAll,
        perCategory: perCategory,
      );
      final unique = <String>{};
      for (final movie in category.movies) {
        final key = keyOf(movie);
        if (!seen.contains(key)) unique.add(key);
      }
      if (unique.length < target && fetchable.contains(category.columnId)) {
        needing.add(category.columnId);
      }
      seen.addAll(unique.take(target));
    }
    return needing;
  }

  /// La grilla sin repetidas. Cada categoría, en orden: sus películas que no
  /// aparecieron antes y después las de [extras] (su lista del servidor),
  /// hasta [targetFor]. Si no llega, se recorta para que los casilleros
  /// (películas + "Ver todas") sean múltiplo de [rowLength] y las filas
  /// queden completas; con menos de [rowLength] casilleros queda como está.
  /// Las categorías sin películas se sacan.
  static List<CategoryColumn> build(
    List<CategoryColumn> categories, {
    Map<int, List<MovieItem>> extras = const {},
    Set<int> withShowAll = const {},
    int perCategory = perCategory,
  }) {
    final seen = <String>{};
    final result = <CategoryColumn>[];
    for (final category in categories) {
      final hasMore = withShowAll.contains(category.columnId);
      final target = targetFor(
        category.columnId,
        withShowAll: withShowAll,
        perCategory: perCategory,
      );
      final picked = <MovieItem>[];
      final pickedKeys = <String>{};
      for (final movie in [...category.movies, ...?extras[category.columnId]]) {
        if (picked.length == target) break;
        final key = keyOf(movie);
        if (seen.contains(key) || !pickedKeys.add(key)) continue;
        picked.add(movie);
      }
      final extra = hasMore ? 1 : 0;
      final slots = picked.length + extra;
      final shown = slots >= rowLength
          ? picked.sublist(0, slots - slots % rowLength - extra)
          : picked;
      if (shown.isEmpty) continue;
      // Sólo lo que se muestra cuenta como visto: lo recortado puede
      // aparecer en una categoría de más abajo.
      seen.addAll(shown.map(keyOf));
      result.add(
        CategoryColumn(
          columnId: category.columnId,
          columnName: category.columnName,
          code: category.code,
          movies: shown,
          hasMore: hasMore,
        ),
      );
    }
    return result;
  }
}
