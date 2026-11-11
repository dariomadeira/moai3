// Genera los íconos del clima de la app (assets/lottie/weather/): baja los
// Lottie de Meteocons y les aplica el recoloreo del REDISEÑO una sola vez,
// así la app no los baja ni los procesa en cada arranque (auditoría del
// Inicio, 2026-11-07).
//
// Uso (desde la raíz del proyecto): dart run tool/build_weather_icons.dart

import 'dart:convert';
import 'dart:io';

const _cdnBase = 'https://cdn.jsdelivr.net/npm/@meteocons/lottie@0.1.0/fill';
const _outDir = 'assets/lottie/weather';

/// Los que usa `WeatherIconMapper`.
const _icons = [
  'clear-day',
  'clear-night',
  'cloudy',
  'fog-day',
  'fog-night',
  'hail',
  'mist',
  'overcast-day',
  'overcast-night',
  'partly-cloudy-day',
  'partly-cloudy-day-drizzle',
  'partly-cloudy-day-rain',
  'partly-cloudy-day-snow',
  'partly-cloudy-night',
  'partly-cloudy-night-drizzle',
  'partly-cloudy-night-rain',
  'partly-cloudy-night-snow',
  'rain',
  'thunderstorms-day',
  'thunderstorms-day-rain',
  'thunderstorms-day-snow',
  'thunderstorms-night',
  'thunderstorms-night-rain',
  'thunderstorms-night-snow',
];

/// REDISEÑO: las nubes, la niebla y la neblina de Meteocons son casi
/// blancas y se pierden sobre el fondo claro: se pasan a grises pizarra.
/// Para darles volumen, los degradados (de arriba abajo) van con más luz
/// arriba y más sombra abajo; el borde toma el color de abajo. Las claves
/// son los colores tal cual vienen en el JSON (r,g,b de 0 a 1); la lluvia,
/// los rayos y la nieve quedan como están.
const Map<String, int> _recolor = {
  // Nube clara: degradado #F3F7FE → #E6EFFC y su borde (#E6EFFC).
  '0.9529411764705882,0.9686274509803922,0.996078431372549': 0xD3DBE6,
  '0.9019607843137255,0.9372549019607843,0.9882352941176471': 0x8796AC,
  // Nube oscura (cubierto): degradado #B0BCCD → #94A3B8 y su borde.
  '0.6901960784313725,0.7372549019607844,0.803921568627451': 0x8E9BB0,
  '0.5803921568627451,0.6392156862745098,0.7215686274509804': 0x4F5D73,
  // Sol: degradado #FBBF24 → #F8AF18 (y sus rayos), más luz y más fondo.
  '0.984313725490196,0.7490196078431373,0.1411764705882353': 0xFCD34D,
  '0.9725490196078431,0.6862745098039216,0.09411764705882353': 0xF59E0B,
  // Luna: degradado #86C3DB → #72B9D5. El claro también es la nieve y el
  // granizo: va un poco más oscuro para que se vean sobre el fondo.
  '0.5254901960784314,0.7647058823529411,0.8588235294117647': 0x6CB4D4,
  '0.4470588235294118,0.7254901960784313,0.8352941176470589': 0x4A9FC4,
  // Líneas de neblina (#D6DFE9) y de niebla (#E2E8F0).
  '0.8392156862745098,0.8745098039215686,0.9137254901960784': 0x8392A8,
  '0.8862745098039215,0.9098039215686274,0.9411764705882353': 0x8392A8,
};

/// REDISEÑO: el contorno de las nubes, el sol y la luna viene de 1 (en
/// 128): en los íconos chicos no se ve. Va más grueso ([_outlineWidth]) y
/// un tono más oscuro que su relleno, para que cada parte se distinga.
/// Las claves son el color original del contorno (como en [_recolor]).
const Map<String, int> _outline = {
  // Nube clara.
  '0.9019607843137255,0.9372549019607843,0.9882352941176471': 0x6B7A91,
  // Nube oscura (cubierto).
  '0.5803921568627451,0.6392156862745098,0.7215686274509804': 0x3E4A5E,
  // Sol.
  '0.9725490196078431,0.6862745098039216,0.09411764705882353': 0xE08600,
  // Luna.
  '0.4470588235294118,0.7254901960784313,0.8352941176470589': 0x3A87AD,
  // Rayo.
  '0.9647058823529412,0.6588235294117647,0.13725490196078433': 0xC27A00,
};
const double _outlineWidth = 3.5;

/// Lo que asoma el borde de cada lado de un trazo sin relleno (las gotas,
/// la niebla): va debajo, más ancho.
const double _strokeEdge = 1.25;

/// El borde que se agrega es el color de la pieza, así de oscuro.
const double _outlineShade = 0.7;

String _rgb(int color) => [
  (color >> 16) & 0xFF,
  (color >> 8) & 0xFF,
  color & 0xFF,
].map((c) => c / 255).join(',');

/// El JSON de Meteocons con los contornos de [_outline], los colores de
/// [_recolor] y un borde en todo lo que no tenía ([_addOutlines]).
String recolor(String json) {
  // Primero los contornos: comparten el color con el relleno.
  _outline.forEach((from, to) {
    json = json.replaceAll(
      '"c":{"a":0,"k":[$from,1]},"w":{"a":0,"k":1}',
      '"c":{"a":0,"k":[${_rgb(to)},1]},"w":{"a":0,"k":$_outlineWidth}',
    );
  });
  _recolor.forEach((from, to) {
    json = json.replaceAll(from, _rgb(to));
  });
  final data = jsonDecode(json) as Map<String, dynamic>;
  void layers(Object? list) {
    if (list is! List) return;
    for (final layer in list.whereType<Map>()) {
      _addOutlines(layer['shapes']);
    }
  }

  layers(data['layers']);
  for (final asset in (data['assets'] as List? ?? const []).whereType<Map>()) {
    layers(asset['layers']);
  }
  return jsonEncode(data);
}

/// REDISEÑO: el borde es lo que da contraste sobre el fondo claro, así que
/// todo lleva uno. En cada grupo de formas del Lottie (la lista `it`, que
/// dibuja primero lo de abajo de la lista):
/// - relleno sin trazo (rayitos del sol, nieve, granizo): un trazo más
///   oscuro detrás del relleno, que asoma por fuera;
/// - trazo sin relleno (gotas, niebla): una copia más ancha y oscura
///   detrás, que asoma a los dos lados.
/// Las nubes, el sol, la luna y el rayo ya traen el suyo ([_outline]).
void _addOutlines(Object? items) {
  if (items is! List) return;
  final paints = <Map>[];
  for (final item in items.whereType<Map>()) {
    if (item['ty'] == 'gr') _addOutlines(item['it']);
    if (const {'fl', 'gf', 'st'}.contains(item['ty'])) paints.add(item);
  }
  if (paints.isEmpty) return;
  final fill = paints.where((p) => p['ty'] == 'fl').firstOrNull;
  final strokes = paints.where((p) => p['ty'] == 'st').toList();
  final hasGradient = paints.any((p) => p['ty'] == 'gf');

  Map<String, dynamic>? outline;
  if (fill != null && strokes.isEmpty && !hasGradient) {
    final color = _staticColor(fill);
    if (color == null) return;
    outline = _stroke(_darker(color), _outlineWidth);
  } else if (fill == null && !hasGradient && strokes.length == 1) {
    final stroke = strokes.single;
    final color = _staticColor(stroke);
    final width = (stroke['w'] as Map?)?['k'];
    if (color == null || width is! num || stroke['_moaiOutline'] == true) {
      return;
    }
    outline = _stroke(_darker(color), width + 2 * _strokeEdge)
      ..['lc'] = stroke['lc'] ?? 2
      ..['lj'] = stroke['lj'] ?? 2;
  }
  if (outline == null) return;
  // Detrás de lo que pinta, antes de la transformación (va última).
  final transform = items.lastIndexWhere((i) => i is Map && i['ty'] == 'tr');
  items.insert(transform < 0 ? items.length : transform, outline);
}

/// El color de un relleno o trazo si no está animado (r,g,b de 0 a 1).
List<num>? _staticColor(Map paint) {
  final color = paint['c'];
  if (color is! Map || color['a'] != 0) return null;
  final k = color['k'];
  if (k is! List || k.length < 3 || k.any((v) => v is! num)) return null;
  return [for (final v in k.take(3)) v as num];
}

List<num> _darker(List<num> rgb) => [for (final v in rgb) v * _outlineShade];

Map<String, dynamic> _stroke(List<num> rgb, num width) => {
  'ty': 'st',
  'nm': 'moai-outline',
  '_moaiOutline': true,
  'o': {'a': 0, 'k': 100},
  'c': {
    'a': 0,
    'k': [...rgb, 1],
  },
  'w': {'a': 0, 'k': width},
  'lc': 2,
  'lj': 2,
};

Future<void> main() async {
  Directory(_outDir).createSync(recursive: true);
  final client = HttpClient();
  try {
    for (final name in _icons) {
      final request = await client.getUrl(Uri.parse('$_cdnBase/$name.json'));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('$name: HTTP ${response.statusCode}');
      }
      final json = await response.transform(utf8.decoder).join();
      final out = File('$_outDir/$name.json')..writeAsStringSync(recolor(json));
      stdout.writeln('${out.path}  ${out.lengthSync()} bytes');
    }
  } finally {
    client.close();
  }
}
