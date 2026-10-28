import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guarda de iconos centralizados (SPEC-50 §4.5): solo `MoaiIcons` conoce las
/// familias de íconos; el resto de la app usa sus constantes.
void main() {
  test('no se usan familias de íconos fuera de MoaiIcons', () {
    final direct = RegExp(
      r'\b(Icons|Symbols|ReiconIcons|ReiconFilledIcons|HugeIcons)\.[a-z]|'
      r'package:(reicons|material_symbols_icons|hugeicons_plus)/',
    );
    final offenders = [
      for (final e in Directory('lib').listSync(recursive: true))
        if (e is File && e.path.endsWith('.dart'))
          if (e.path.replaceAll(r'\', '/') case final path
              when !path.endsWith('lib/theme/moai_icons.dart') &&
                  direct.hasMatch(e.readAsStringSync()))
            path,
    ];
    expect(offenders, isEmpty);
  });

  test('los tamaños de íconos salen de MoaiIconSizes', () {
    final literal = RegExp(r'\b(size|iconSize)\s*[:=]\s*[0-9]');
    final offenders = <String>[];
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final source = e.readAsStringSync();
      // `iconSize` en cualquier lado; `size:` solo dentro de `Icon(...)`.
      for (final m in RegExp(r'\biconSize\s*[:=]\s*[0-9]').allMatches(source)) {
        offenders.add('${e.path}: ${m[0]}');
      }
      for (final m in RegExp(r'\bIcon\(').allMatches(source)) {
        var depth = 0;
        var end = m.end - 1;
        for (; end < source.length; end++) {
          if (source[end] == '(') depth++;
          if (source[end] == ')' && --depth == 0) break;
        }
        final call = source.substring(m.start, end);
        if (literal.hasMatch(call)) offenders.add('${e.path}: $call');
      }
    }
    expect(offenders, isEmpty);
  });

  test('MoaiIcons usa solo HugeIcons (sin Material Icons, Symbols ni Reicon)', () {
    final source = File('lib/theme/moai_icons.dart').readAsStringSync();
    final values = RegExp(r'static const \w+ = (\w+)\.')
        .allMatches(source)
        .map((m) => m[1])
        .toSet();
    expect(values, {'HugeIcons'});
    expect(source, isNot(contains('package:material_symbols_icons')));
    expect(source, isNot(contains('package:reicons')));
  });
}
