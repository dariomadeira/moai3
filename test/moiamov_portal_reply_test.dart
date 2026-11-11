import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/moiamov_crypto.dart';

void main() {
  final key = base64.encode(List<int>.generate(24, (i) => i * 7 + 3));

  String reply(Map<String, dynamic> data, {String code = '0'}) => jsonEncode({
    'returnCode': code,
    'errorMessage': 'motivo',
    'data': MoiamovCrypto.encrypt(jsonEncode(data), key),
  });

  group('respuesta del portal leída en otro hilo', () {
    test('descifra y arma películas y series, sin adelantos', () async {
      final items = await MoiamovApiService.debugReadShelf(
        reply({
          'assetList': [
            {'contentId': '1', 'name': 'Una', 'releaseTime': '2024-05-01'},
            {'contentId': '2', 'name': 'Serie', 'programType': 'teleplay'},
            {'contentId': '3', 'name': 'Adelanto', 'programType': 'trailer'},
          ],
        }),
        key: key,
      );

      // Quien la usa se queda con lo suyo (Películas o Series).
      expect([for (final m in items!) m.contentId], ['1', '2']);
      expect(items.first.formattedYear, '2024');
      // Los valores calculados de a poco siguen andando al volver.
      expect(items.first.isMovie, isTrue);
      expect(items.last.isSeries, isTrue);
      expect(items.first.stageImages, isEmpty);
    });

    test('el rechazo del portal da null', () async {
      expect(
        await MoiamovApiService.debugReadShelf(
          reply({'assetList': []}, code: '500'),
          key: key,
        ),
        isNull,
      );
    });

    test('una respuesta inválida o mal cifrada da null', () async {
      expect(
        await MoiamovApiService.debugReadShelf('<html>', key: key),
        isNull,
      );
      expect(
        await MoiamovApiService.debugReadShelf(
          jsonEncode({'returnCode': '0', 'data': 'zz'}),
          key: key,
        ),
        isNull,
      );
    });
  });
}
