import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guarda de iconos centralizados (SPEC-50 §4.5): solo `MoaiIcons` conoce las
/// familias de íconos; el resto de la app usa sus constantes.
void main() {
  test('no se usan familias de íconos fuera de MoaiIcons', () {
    final direct = RegExp(
      r'\b(Icons|Symbols|ReiconIcons|ReiconFilledIcons)\.[a-z]|'
      r'package:(reicons|material_symbols_icons)/',
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

  test('MoaiIcons usa solo Reicon (sin Material Icons ni Symbols)', () {
    final source = File('lib/theme/moai_icons.dart').readAsStringSync();
    final values = RegExp(r'static const \w+ = (\w+)\.')
        .allMatches(source)
        .map((m) => m[1])
        .toSet();
    expect(values, {'ReiconIcons', 'ReiconFilledIcons'});
    expect(source, isNot(contains('package:material_symbols_icons')));
  });
}
