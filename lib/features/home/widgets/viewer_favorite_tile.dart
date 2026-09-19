import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/services/moai_image_cache_manager.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_list_card_style.dart';

class ViewerFavoriteTile extends StatefulWidget {
  final Channel channel;
  final bool isSelected;
  final FocusNode? focusNode;
  final VoidCallback onTap;

  const ViewerFavoriteTile({
    super.key,
    required this.channel,
    required this.isSelected,
    required this.onTap,
    this.focusNode,
  });

  @override
  State<ViewerFavoriteTile> createState() => _ViewerFavoriteTileState();
}

class _ViewerFavoriteTileState extends State<ViewerFavoriteTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final itemStyle = TvListCardStyle.resolve(
      scheme: scheme,
      focused: _isFocused,
      selected: widget.isSelected,
    );

    return SizedBox(
      width: TvLayoutConstants.viewerFavoriteTileWidth,
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (focus) => setState(() => _isFocused = focus),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: itemStyle.backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ColoredBox(
                    color: Colors.white,
                    child: SizedBox(
                      width: 48,
                      height: 32,
                      child: Padding(
                        padding: widget.channel.logoUrl.startsWith('http')
                            ? const EdgeInsets.all(3)
                            : EdgeInsets.zero,
                        child: _ChannelLogo(logoUrl: widget.channel.logoUrl),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: MoaiText.body(
                    context,
                    color: itemStyle.foregroundColor,
                    fontSize: 11,
                    fontWeight: itemStyle.fontWeight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  final String logoUrl;

  const _ChannelLogo({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    const placeholder = Icon(
      Symbols.tv_gen,
      color: Colors.black45,
      size: 22,
    );

    final cleanUrl = logoUrl.trim();
    if (cleanUrl.isEmpty) {
      return placeholder;
    }

    if (cleanUrl.startsWith('http')) {
      final isSvg = cleanUrl.toLowerCase().contains('.svg');
      if (isSvg) {
        return SvgPicture.network(
          cleanUrl,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          headers: const {'User-Agent': 'Mozilla/5.0 (Linux; Android 10) MoaiTV/1.0'},
          placeholderBuilder: (_) => placeholder,
          errorBuilder: (_, _, _) => placeholder,
        );
      }
      return CachedNetworkImage(
        imageUrl: cleanUrl,
        cacheKey: MoaiImageCacheManager.cleanCacheKey(cleanUrl),
        cacheManager: MoaiImageCacheManager.instance,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        memCacheHeight: 120,
        fadeInDuration: const Duration(milliseconds: 80),
        filterQuality: FilterQuality.medium,
        httpHeaders: const {'User-Agent': 'Mozilla/5.0 (Linux; Android 10) MoaiTV/1.0'},
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      );
    }
    return Image.asset(
      cleanUrl,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

