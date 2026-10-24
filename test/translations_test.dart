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

  test('es.json está ordenado alfabéticamente', () {
    final keys = (jsonDecode(
      File('assets/translations/es.json').readAsStringSync(),
    ) as Map<String, dynamic>)
        .keys
        .toList();
    expect(keys, [...keys]..sort());
  });

  test('no hay textos de interfaz hardcodeados', () {
    // Literales en los lugares donde un texto llega a pantalla: widgets,
    // parámetros de etiqueta, mensajes de error y valores por defecto.
    final hardcoded = RegExp(
      r'''(Text\(|label:|title:|tooltip:|message:|description:|hintText:|'''
      r'''subtitle:|statusMessage:|playLabel:|titles:\s*\[|Exception\(|'''
      r'''lastResolutionError\s*\?*=|\?\?)\s*'([^'$\n]*)'(?!\s*:)''',
    );
    // Parece texto para una persona: dos palabras, acentos o una palabra
    // con mayúscula inicial.
    final phrase = RegExp(
      r'[a-záéíóúñ]{2,} [a-záéíóúñ]{2,}|[áéíóúñ¿¡]|[A-ZÁÉÍÓÚ][a-záéíóú]{3,}',
    );
    const allowedTexts = {
      'MOAI-', // prefijo del código de amigo: es marca
      'Capcom', // empresa por defecto de las ROMs: nombre propio
      // Mensajes internos que solo van al log.
      'session subscribe failed',
      'Tiempo de espera agotado al conectar con Supabase (10s)',
      'Dispositivo no encontrado',
    };
    final offenders = [
      for (final e in sources.entries)
        for (final m in hardcoded.allMatches(e.value))
          if (phrase.hasMatch(m[2]!) && !allowedTexts.contains(m[2]))
            '${e.key}: ${m[2]}',
    ];
    expect(offenders, isEmpty);
  });
}
