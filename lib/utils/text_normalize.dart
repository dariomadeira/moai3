/// Normaliza texto para comparar: minúsculas, sin tildes ni signos y con un
/// solo espacio entre palabras. `null` o vacío devuelve `''` (SPEC-50 §2.10).
String normalizeText(String? text) {
  if (text == null || text.isEmpty) return '';
  var clean = text.toLowerCase();
  const withDia = 'áéíóúüñàèìòù';
  const withoutDia = 'aeiouunaeiou';
  for (var i = 0; i < withDia.length; i++) {
    clean = clean.replaceAll(withDia[i], withoutDia[i]);
  }
  return clean
      .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
