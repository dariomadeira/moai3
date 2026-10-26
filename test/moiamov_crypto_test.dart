import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/moiamov_api_service.dart';
import 'package:moai3/services/moiamov_crypto.dart';

void main() {
  // Clave de prueba de 24 bytes (32 caracteres en base64).
  const key = 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3';

  setUp(() => dotenv.loadFromString(envString: 'MOIAMOV_PORTAL_KEY=$key'));

  test('ida y vuelta', () {
    const plain = '{"película":"Coco","año":2017}';
    expect(
      MoiamovCrypto.decrypt(MoiamovCrypto.encrypt(plain, key), key),
      plain,
    );
  });

  test('compatible con el servicio: lo que cifra uno lo lee el otro', () {
    final fromService = MoiamovApiService.encryptPayload({'a': 1});
    final decoded = jsonDecode(MoiamovCrypto.decrypt(fromService, key)) as Map;
    expect(decoded['a'], 1);
    expect(decoded['loginType'], '2');

    final fromCrypto = MoiamovCrypto.encrypt('hola', key);
    expect(MoiamovApiService.decryptDocument(fromCrypto, key: key), 'hola');
  });

  test('salida en hex de base64, como la app oficial', () {
    final hex = MoiamovCrypto.encrypt('x', key);
    expect(RegExp(r'^[0-9a-f]+$').hasMatch(hex), isTrue);
    // Cada carácter base64 ocupa dos dígitos hex.
    expect(hex.length.isEven, isTrue);
  });

  test('md5 en hex minúscula', () {
    expect(MoiamovCrypto.md5Hex('abc'), '900150983cd24fb0d6963f7d28e17f72');
  });
}
