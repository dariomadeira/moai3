import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/utils/text_normalize.dart';

void main() {
  test('normalizeText quita tildes, signos y espacios de más', () {
    expect(normalizeText('  Música   & Películas!  '), 'musica peliculas');
    expect(normalizeText('NIÑOS'), 'ninos');
    expect(normalizeText(null), '');
  });

  test('el ícono de categoría no depende de tildes ni mayúsculas', () {
    expect(
      MoaiIcons.tvCategoryIconFor('musica'),
      MoaiIcons.tvCategoryIconFor('Música'),
    );
    expect(MoaiIcons.tvCategoryIconFor('PELICULAS'), MoaiIcons.tvCategoryCine);
    expect(
      MoaiIcons.tvCategoryIconFor('Inexistente'),
      MoaiIcons.tvCategoryFallback,
    );
  });
}
