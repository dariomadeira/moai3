import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guarda de traducciones centralizadas (SPEC-50 §3.6).
void main() {
  final translations = (jsonDecode(
    File('assets/translations/es.json').readAsStringSync(),
  ) as Map<String, dynamic>)
      .keys
      .toSet();

  final sources = {
    for (final e in Directory('lib').listSync(recursive: true))
      if (e is File &&
          e.path.endsWith('.dart') &&
          !e.path.replaceAll('\\', '/').contains('lib/l10n/'))
        e.path.replaceAll('\\', '/'): e.readAsStringSync(),
  };
  final allCode = sources.values.join('\n');

  test('LocaleKeys está sincronizado con es.json', () {
    final generated = File('lib/l10n/locale_keys.g.dart').readAsStringSync();
    final keys = RegExp(r"static const (\w+) = '\1';")
        .allMatches(generated)
        .map((m) => m[1]!)
        .toSet();
    expect(
      keys,
      translations,
      reason: 'Regenerar: dart run easy_localization:generate -f keys '
          '-o locale_keys.g.dart -S assets/translations -O lib/l10n',
    );
  });

  test('no hay claves sin uso', () {
    final unused = translations
        .where((k) => !allCode.contains('LocaleKeys.$k'))
        .toList()
      ..sort();
    expect(unused, isEmpty);
  });

  test('las traducciones usan LocaleKeys, no literales', () {
    final literal = RegExp(r"""['"][a-z0-9_]+['"]\.tr\(""");
    final offenders = [
      for (final e in sources.entries)
        if (literal.hasMatch(e.value)) e.key,
    ];
    expect(offenders, isEmpty);
  });

  test('no hay textos de interfaz hardcodeados', () {
    // Text('...') con al menos una palabra. Películas queda fuera de alcance.
    final hardcoded = RegExp(r"Text\(\s*'([^'$]*[A-Za-zÁÉÍÓÚáéíóúñ]{3,}[^']*)'");
    const allowedFiles = ['lib/features/movies/', 'tv_movie', 'home_movies_area'];
    // Prefijo del código de amigo: es marca, no se traduce.
    const allowedTexts = {'MOAI-'};
    final offenders = [
      for (final e in sources.entries)
        if (!allowedFiles.any(e.key.contains))
          for (final m in hardcoded.allMatches(e.value))
            if (!allowedTexts.contains(m[1])) '${e.key}: ${m[1]}',
    ];
    expect(offenders, isEmpty);
  });
}
