import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/block/desede_engine.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/digests/md5.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';
import 'package:pointycastle/pointycastle.dart';

/// Cifrado del portal Moiamov, igual que la app oficial: 3DES/ECB/PKCS7 y el
/// resultado como hex(base64(cifrado)).
///
/// Sólo funciones puras: se pueden usar en otro hilo (las claves se pasan,
/// no se leen de .env).
class MoiamovCrypto {
  const MoiamovCrypto._();

  /// Cifra [plain] con [key] (base64) y lo devuelve en hex(base64(cifrado)),
  /// como `fc.b.b` y `AbstractC4310b.m18077b` del APK.
  static String encrypt(String plain, String key) {
    final cipher = _cipher(forEncryption: true, key: key);
    final encrypted = cipher.process(Uint8List.fromList(utf8.encode(plain)));
    return _toHex(base64.encode(encrypted));
  }

  /// Descifra un hex(base64(cifrado)) con [key] (base64).
  static String decrypt(String hexData, String key) {
    final cipher = _cipher(forEncryption: false, key: key);
    final decrypted = cipher.process(base64Decode(_fromHex(hexData)));
    return utf8.decode(decrypted, allowMalformed: true);
  }

  /// MD5 en hex minúscula (replica AbstractC5097i.m20666a del APK).
  static String md5Hex(String input) {
    final digest = MD5Digest();
    final bytes = digest.process(Uint8List.fromList(utf8.encode(input)));
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write((b & 0xff).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString().toLowerCase();
  }

  static PaddedBlockCipherImpl _cipher({
    required bool forEncryption,
    required String key,
  }) {
    var keyBytes = base64Decode(key);
    if (keyBytes.length > 24) {
      keyBytes = Uint8List.fromList(keyBytes.sublist(0, 24));
    }
    return PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(DESedeEngine()))
      ..init(
        forEncryption,
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          KeyParameter(keyBytes),
          null,
        ),
      );
  }

  /// Base64 como lo decodifica la app oficial: saltea saltos de línea y
  /// descarta un grupo final incompleto.
  static Uint8List base64Decode(String str) {
    const pem =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final pemMap = List<int>.filled(256, -1);
    for (int i = 0; i < pem.length; i++) {
      pemMap[pem.codeUnitAt(i)] = i;
    }

    final bytes = latin1.encode(str);
    final out = <int>[];
    int idx = 0;
    while (idx < bytes.length) {
      final buf = <int>[];
      while (idx < bytes.length && buf.length < 4) {
        final b = bytes[idx++];
        if (b != 10 && b != 13) {
          buf.add(b);
        }
      }
      if (buf.length == 4) {
        final b0 = pemMap[buf[0]];
        final b1 = pemMap[buf[1]];
        final b2 = pemMap[buf[2]];
        final b3 = pemMap[buf[3]];
        if (buf[2] == 61) {
          out.add(((b0 << 2) & 0xFC) | ((b1 >> 4) & 0x03));
        } else if (buf[3] == 61) {
          out.add(((b0 << 2) & 0xFC) | ((b1 >> 4) & 0x03));
          out.add(((b1 << 4) & 0xF0) | ((b2 >> 2) & 0x0F));
        } else {
          out.add(((b0 << 2) & 0xFC) | ((b1 >> 4) & 0x03));
          out.add(((b1 << 4) & 0xF0) | ((b2 >> 2) & 0x0F));
          out.add(((b2 << 6) & 0xC0) | (b3 & 0x3F));
        }
      }
    }
    return Uint8List.fromList(out);
  }

  static String _toHex(String str) {
    final sb = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      sb.write(str.codeUnitAt(i).toRadixString(16));
    }
    return sb.toString();
  }

  static String _fromHex(String hex) {
    final sb = StringBuffer();
    for (int i = 0; i < hex.length; i += 2) {
      sb.writeCharCode(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return sb.toString();
  }
}
