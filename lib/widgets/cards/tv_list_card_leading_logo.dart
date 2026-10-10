import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moai3/services/moai_image_cache_manager.dart';
import 'package:moai3/theme/app_icons.dart';

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

  /// Consulta si la URL del logo falló previamente o está vacía.
  static bool isUrlFailed(String url) {
    final clean = url.trim();
    return clean.isEmpty || _TvListCardLeadingLogoState._failedUrls.contains(clean);
  }

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
  static final Set<String> _failedUrls = {};
  bool? _lastReported;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    final url = widget.logoUrl.trim();
    if (_failedUrls.contains(url)) {
      _report(false);
    } else {
      _startLogoTimeout();
    }
  }

  @override
  void didUpdateWidget(covariant TvListCardLeadingLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logoUrl != widget.logoUrl) {
      _lastReported = null;
      final url = widget.logoUrl.trim();
      if (_failedUrls.contains(url)) {
        _report(false);
      } else {
        _startLogoTimeout();
      }
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startLogoTimeout() {
    _timeoutTimer?.cancel();
    final url = widget.logoUrl.trim();
    if (url.isEmpty || _failedUrls.contains(url)) {
      _report(false);
      return;
    }
    _timeoutTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _lastReported == null) {
        _report(false);
      }
    });
  }

  void _report(bool available) {
    final url = widget.logoUrl.trim();
    if (!available && url.isNotEmpty) {
      _failedUrls.add(url);
    }
    if (_lastReported == available) return;
    _lastReported = available;
    _timeoutTimer?.cancel();
    final cb = widget.onLogoResolved;
    if (cb == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        cb(available);
      }
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
      child: AppIcon(
        icon: AppIcons.tv,
        color: iconColor,
        size: (widget.height * 0.55).clamp(0.0, 48.0),
      ),
    );
    const loadingPlaceholder = SizedBox.shrink();

    final cleanUrl = widget.logoUrl.trim();
    final Widget logoContent;

    if (cleanUrl.isEmpty || _lastReported == false || _failedUrls.contains(cleanUrl)) {
      logoContent = errorPlaceholder;
    } else if (cleanUrl.startsWith('http')) {
      final cleanPath = cleanUrl.toLowerCase().split('?').first.split('#').first;
      final isSvg = cleanPath.endsWith('.svg');
      if (isSvg) {
        logoContent = SvgPicture.network(
          cleanUrl,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          headers: const {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) MoaiTV/1.0',
          },
          placeholderBuilder: (_) => loadingPlaceholder,
          errorBuilder: (context, error, stackTrace) {
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
          errorWidget: (context, url, error) {
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
        errorBuilder: (context, error, stackTrace) {
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

    final safePadding = EdgeInsets.symmetric(
      horizontal: (widget.width * 0.1).clamp(0.0, 7.0),
      vertical: (widget.height * 0.1).clamp(0.0, 5.5),
    );

    return SizedBox(
      width: widget.width.clamp(0.0, double.infinity),
      height: widget.height.clamp(0.0, double.infinity),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        padding: safePadding,
        child: logoContent,
      ),
    );
  }
}
