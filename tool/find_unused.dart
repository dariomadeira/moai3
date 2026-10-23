// SPEC-50 §0.3: detector de miembros públicos sin uso.
//
// El analizador solo avisa de privados sin uso. Este script lista
// declaraciones de `lib/` cuyo identificador aparece una sola vez en todo
// `lib/` (la propia declaración). Es heurístico: confirmar con `grep -rw`
// antes de borrar.
//
// Uso: dart run tool/find_unused.dart
import 'dart:io';

const _skip = {
  'build', 'dispose', 'initState', 'didUpdateWidget', 'didChangeDependencies',
  'createState', 'toString', 'hashCode', 'main', 'toJson', 'fromJson',
  'copyWith', 'paint', 'shouldRepaint', 'debugFillProperties', 'call',
  'didChangeAppLifecycleState', 'deactivate', 'activate', 'getClip',
  'shouldReclip', 'lerp', 'isSupported', 'load', 'shouldReload', 'invoke',
  'onKeyEvent',
};

final _declaration = RegExp(
  r'^\s*(?:@override\s+)?(?:static\s+)?'
  r'(?:(?:final|const|late|void|bool|int|double|String|Widget|dynamic|'
  r'Future<[^>]*>|Stream<[^>]*>|[A-Z][A-Za-z0-9_<>,?]*\??)\s+)+'
  r'(?:get\s+)?([a-zA-Z_][A-Za-z0-9_]*)\s*(?:\(|=|;|=>|\{)',
  multiLine: true,
);
final _identifier = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');

void main() {
  final sources = _readDart('lib');
  final tests = _readDart('test').values.join('\n');

  final counts = <String, int>{};
  for (final text in sources.values) {
    for (final m in _identifier.allMatches(text)) {
      counts[m[0]!] = (counts[m[0]!] ?? 0) + 1;
    }
  }

  final found = <String>[];
  sources.forEach((path, text) {
    for (final m in _declaration.allMatches(text)) {
      final name = m[1]!;
      if (_skip.contains(name) || (counts[name] ?? 0) > 1) continue;
      final line = '\n'.allMatches(text.substring(0, m.start)).length + 1;
      final onlyTests = tests.contains(name) ? '  (solo tests)' : '';
      found.add('$path:$line  $name$onlyTests');
    }
  });

  found
    ..sort()
    ..forEach(stdout.writeln);
  stdout.writeln('\n${found.length} candidatos');
}

Map<String, String> _readDart(String dir) => {
      for (final e in Directory(dir).listSync(recursive: true))
        if (e is File && e.path.endsWith('.dart'))
          e.path.replaceAll(Platform.pathSeparator, '/'): e.readAsStringSync(),
    };
