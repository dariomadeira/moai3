import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moai3/services/moai_image_cache_manager.dart';
import 'package:moai3/widgets/cards/safe_network_svg.dart';

/// Renderizador de banderas remotas provistas dinámicamente por los plugins vía HTTP.
abstract final class CountryFlagAssets {
  /// Leading de la fila de país. Si [flagUrl] está presente, se renderiza remotamente con caché.
  /// Si no hay bandera, retorna null para mostrar el icono por defecto.
  static Widget? leadingFor(String country, {String? flagUrl}) {
    if (flagUrl == null || flagUrl.trim().isEmpty) return null;
    final cleanUrl = flagUrl.trim();
    return SizedBox(
      width: 36,
      height: 36,
      child: Center(
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          child: _NetworkFlagImage(url: cleanUrl),
        ),
      ),
    );
  }
}

class _NetworkFlagImage extends StatelessWidget {
  final String url;

  const _NetworkFlagImage({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.toLowerCase().endsWith('.svg')) {
      return SafeNetworkSvg(
        url: url,
        width: 30,
        height: 20,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => const SizedBox(width: 30, height: 20),
        errorBuilder: (_, _, _) => const SizedBox(width: 30, height: 20),
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: MoaiImageCacheManager.cleanCacheKey(url),
      cacheManager: MoaiImageCacheManager.instance,
      width: 30,
      height: 20,
      fit: BoxFit.cover,
      memCacheWidth: 80,
      memCacheHeight: 60,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => const SizedBox(width: 30, height: 20),
      errorWidget: (_, _, _) => const SizedBox(width: 30, height: 20),
    );
  }
}
