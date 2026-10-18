import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Banderas locales para los nombres de país que ya usa el catálogo.
abstract final class CountryFlagAssets {
  static const _assets = <String, String>{
    'argentina': 'assets/flags/ar.svg',
    'brasil': 'assets/flags/br.svg',
    'brazil': 'assets/flags/br.svg',
    'canada': 'assets/flags/ca.svg',
    'paraguay': 'assets/flags/py.svg',
    'uruguay': 'assets/flags/uy.svg',
  };

  static const _accents = <String, String>{
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
  };

  static String? assetFor(String country) {
    return _assets[normalize(country)];
  }

  static String normalize(String country) {
    final buffer = StringBuffer();
    for (final char in country.trim().toLowerCase().split('')) {
      buffer.write(_accents[char] ?? char);
    }
    return buffer.toString();
  }

  /// Leading de la fila. Vacío si el nombre no es uno de los países conocidos.
  static Widget? leadingFor(String country) {
    final asset = assetFor(country);
    if (asset == null) return null;
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          child: _FlagImage(asset),
        ),
      ),
    );
  }
}

class _FlagImage extends StatelessWidget {
  final String asset;

  const _FlagImage(this.asset);

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: 30,
      height: 20,
      fit: BoxFit.cover,
    );
  }
}
