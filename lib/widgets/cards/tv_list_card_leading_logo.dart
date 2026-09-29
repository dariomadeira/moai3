import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moai3/services/moai_image_cache_manager.dart';

/// Leading rectangular para logos de canal con la misma estética que [TvListCardLeadingIcon].
/// Usa `scheme.primaryContainer` (o `onPrimary` con opacidad al tener foco), manteniendo
/// consistencia visual completa con el resto de los ítems de lista (países, categorías, etc.).
class TvListCardLeadingLogo extends StatefulWidget {
  final String logoUrl;
  final double width;
  final double height;
  final bool isFocused;
  /// Padding interno del logo. Por defecto el de listas TV.
  final EdgeInsetsGeometry contentPadding;
  /// `true` si hay imagen real; `false` si URL vacía o falló la carga.
  final ValueChanged<bool>? onLogoResolved;

  const TvListCardLeadingLogo({
    super.key,
    required this.logoUrl,
    required this.width,
    required this.height,
    this.isFocused = false,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 7, vertical: 5.5),
    this.onLogoResolved,
  });

  @override
  State<TvListCardLeadingLogo> createState() => _TvListCardLeadingLogoState();
}

class _TvListCardLeadingLogoState extends State<TvListCardLeadingLogo> {
  bool? _lastReported;

  @override
  void initState() {
    super.initState();
    if (widget.logoUrl.trim().isEmpty) {
      _report(false);
    }
  }

  @override
  void didUpdateWidget(covariant TvListCardLeadingLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logoUrl != widget.logoUrl) {
      _lastReported = null;
      if (widget.logoUrl.trim().isEmpty) {
        _report(false);
      }
    }
  }

  void _report(bool available) {
    if (_lastReported == available) return;
    _lastReported = available;
    final cb = widget.onLogoResolved;
    if (cb == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cb(available);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focusedIconColor =
        Color.lerp(scheme.onPrimary, scheme.onPrimaryContainer, 0.38) ??
            scheme.onPrimary;
    final iconColor =
        widget.isFocused ? focusedIconColor : scheme.onPrimaryContainer;

    final errorPlaceholder = Center(
      child: Icon(
        Icons.tv_outlined,
        color: iconColor,
        size: widget.height * 0.55,
      ),
    );
    const loadingPlaceholder = SizedBox.shrink();

    final cleanUrl = widget.logoUrl.trim();
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
          headers: const {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) MoaiTV/1.0',
          },
          placeholderBuilder: (_) => loadingPlaceholder,
          errorBuilder: (_, _, _) {
            _report(false);
            return errorPlaceholder;
          },
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
          errorWidget: (_, _, _) {
            _report(false);
            return errorPlaceholder;
          },
          imageBuilder: (context, imageProvider) {
            _report(true);
            return Image(
              image: imageProvider,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              filterQuality: FilterQuality.medium,
            );
          },
        );
      }
    } else {
      logoContent = Image.asset(
        cleanUrl,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) {
          _report(false);
          return errorPlaceholder;
        },
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) {
            _report(true);
          }
          return child;
        },
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        padding: widget.contentPadding,
        child: logoContent,
      ),
    );
  }
}
