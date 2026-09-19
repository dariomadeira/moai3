import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_logo.dart';
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
                TvListCardLeadingLogo(
                  logoUrl: widget.channel.logoUrl,
                  width: 48,
                  height: 32,
                  isFocused: _isFocused,
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

