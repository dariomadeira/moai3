import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moai3/services/moai_image_cache_manager.dart';

/// Leading rectangular para logos de canal con la misma estética que [TvListCardLeadingIcon].
/// Usa `scheme.primaryContainer` (o `onPrimary` con opacidad al tener foco), manteniendo 
/// consistencia visual completa con el resto de los ítems de lista (países, categorías, etc.).
class TvListCardLeadingLogo extends StatelessWidget {
  final String logoUrl;
  final double width;
  final double height;
  final bool isFocused;

  const TvListCardLeadingLogo({
    super.key,
    required this.logoUrl,
    required this.width,
    required this.height,
    this.isFocused = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // final containerBg = isFocused
    //     ? scheme.onPrimary.withValues(alpha: 0.18)
    //     : scheme.primaryContainer;
    final iconColor = isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;

    final errorPlaceholder = Center(
      child: Icon(
        Icons.tv_outlined,
        color: iconColor,
        size: height * 0.55,
      ),
    );
    // Sin ícono durante la carga: el logo hace fade limpio encima.
    const loadingPlaceholder = SizedBox.shrink();

    final cleanUrl = logoUrl.trim();
    final Widget logoContent;

    if (cleanUrl.isEmpty) {
      logoContent = errorPlaceholder;
    } else if (cleanUrl.startsWith('http')) {
      final isSvg = cleanUrl.toLowerCase().contains('.svg');
      if (isSvg) {
        logoContent = SvgPicture.network(
          cleanUrl,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          headers: const {'User-Agent': 'Mozilla/5.0 (Linux; Android 10) MoaiTV/1.0'},
          placeholderBuilder: (_) => loadingPlaceholder,
          errorBuilder: (_, _, _) => errorPlaceholder,
        );
      } else {
        logoContent = CachedNetworkImage(
          imageUrl: cleanUrl,
          cacheKey: MoaiImageCacheManager.cleanCacheKey(cleanUrl),
          cacheManager: MoaiImageCacheManager.instance,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          memCacheHeight: 120,
          fadeInDuration: const Duration(milliseconds: 220),
          fadeOutDuration: const Duration(milliseconds: 180),
          fadeInCurve: Curves.easeOutCubic,
          fadeOutCurve: Curves.easeOut,
          filterQuality: FilterQuality.medium,
          httpHeaders: const {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) MoaiTV/1.0',
          },
          placeholder: (_, _) => loadingPlaceholder,
          errorWidget: (_, _, _) => errorPlaceholder,
        );
      }
    } else {
      logoContent = Image.asset(
        cleanUrl,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => errorPlaceholder,
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          // color: containerBg,
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5.5),
        child: logoContent,
      ),
    );
  }
}
