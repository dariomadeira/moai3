import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/moiamov_catalog_store.dart';

void main() {
  // Clave de prueba de 24 bytes (32 caracteres en base64).
  const key = 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3';

  setUp(() => dotenv.loadFromString(envString: 'MOIAMOV_PORTAL_KEY=$key'));

  /// Una respuesta del portal con [columns] cifradas como las manda.
  Uint8List response(List<Map<String, Object>> columns, {String code = '0'}) {
    final data = MoiamovApiService.encryptPayload({'recommendList': columns});
    return utf8.encode(jsonEncode({'returnCode': code, 'data': data}));
  }

  final columns = [
    {
      'name': 'Acción',
      'assetList': [
        {'contentId': 'a1', 'name': 'Una'},
        {'contentId': 'a2', 'name': 'Dos'},
      ],
    },
    {'name': 'Vacía', 'assetList': <Object>[]},
    {
      'name': 'Drama',
      'assetList': [
        {'contentId': 'd1', 'name': 'Tres'},
      ],
    },
  ];

  test('en otro hilo: descifra, cuenta y guarda en disco', () async {
    final dir = await Directory.systemTemp.createTemp('catalogo');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/masnew_movies.json';
    final body = response(columns);

    // Como en la app: la clave y la ruta van desde este hilo.
    final download = await Isolate.run(
      () => MoiamovCatalogStore.processDownload(body, key: key, savePath: path),
    );

    expect(download.ok, isTrue);
    expect(download.categories, 2); // la vacía no cuenta
    expect(download.titles, 3);
    expect(download.saved, isTrue);
    final saved = jsonDecode(File(path).readAsStringSync()) as Map;
    expect((saved['recommendList'] as List).length, 3);
  });

  test('sin ruta no guarda nada', () {
    final download = MoiamovCatalogStore.processDownload(
      response(columns),
      key: key,
    );
    expect(download.titles, 3);
    expect(download.saved, isFalse);
  });

  test('sesión no válida: devuelve el código y no descifra', () {
    final download = MoiamovCatalogStore.processDownload(
      utf8.encode(
        jsonEncode({'returnCode': 'aaa100028', 'errorMessage': 'sesión'}),
      ),
      key: key,
    );
    expect(download.ok, isFalse);
    expect(download.returnCode, 'aaa100028');
    expect(download.errorMessage, 'sesión');
  });

  test('con otra clave avisa que no pudo descifrar', () {
    final download = MoiamovCatalogStore.processDownload(
      response(columns),
      key: 'OTEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3',
    );
    expect(download.ok, isTrue);
    expect(download.titles, 0);
    expect(download.decryptError, isNotNull);
  });

  test('una respuesta que no es JSON de objeto no rompe', () {
    final download = MoiamovCatalogStore.processDownload(
      utf8.encode('[]'),
      key: key,
    );
    expect(download.returnCode, isNull);
  });

  test(
    'el catálogo guardado se arma en otro hilo con los textos de acá',
    () async {
      const strings = CatalogStrings(
        untitled: 'Sin título',
        defaultCategory: 'Varias',
        trailersCategory: 'Adelantos',
      );
      final raw = jsonEncode({
        'recommendList': [
          {
            'name': 'Trailer',
            'assetList': [
              {'contentId': 't1'},
            ],
          },
          {'name': 'Vacía', 'assetList': <Object>[]},
          {
            'assetList': [
              {'contentId': 'x1', 'name': 'Una'},
            ],
          },
        ],
      });

      final categories = await Isolate.run(
        () => MoiamovCatalogStore.parseCategories(raw, strings),
      );

      expect(categories.map((c) => c.columnName), ['Adelantos', 'Varias']);
      expect(categories.first.movies.single.name, 'Sin título');
    },
  );
}
