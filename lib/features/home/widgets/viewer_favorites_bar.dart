import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/focus/tv_intents.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/channel_grid_tile.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

class ViewerFavoritesBar extends StatelessWidget {
  final List<Channel> favoriteChannels;
  final Channel? selectedChannel;
  final ScrollController scrollController;
  final List<FocusNode> focusNodes;
  final ValueChanged<Channel> onSelect;
  final ValueChanged<int> onFocusPrevious;
  final ValueChanged<int> onFocusNext;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;
  final VoidCallback? onFocusLeft;
  final VoidCallback? onFocusRight;
  final Widget? headerAction;

  const ViewerFavoritesBar({
    super.key,
    required this.favoriteChannels,
    required this.selectedChannel,
    required this.scrollController,
    required this.focusNodes,
    required this.onSelect,
    required this.onFocusPrevious,
    required this.onFocusNext,
    required this.onKeyUp,
    required this.onKeyDown,
    this.onFocusLeft,
    this.onFocusRight,
    this.headerAction,
  });

  /// La ficha ([ChannelGridTile]) ya trae media separación arriba y abajo
  /// (la de la grilla): se descuenta para que abajo quede el mismo margen que
  /// a los costados.
  static const _contentPadding = EdgeInsets.fromLTRB(
    TvLayoutConstants.viewerFavoritesBarPaddingStart,
    TvLayoutConstants.viewerFavoritesBarPaddingStart - ChannelGridTile.gap / 2,
    TvLayoutConstants.viewerFavoritesBarPaddingEnd,
    TvLayoutConstants.viewerFavoritesBarPaddingStart - ChannelGridTile.gap / 2,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  LocaleKeys.home_tv_favorites.tr(),
                  style: MoaiText.display(
                    context,
                    color: scheme.onSurface,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              ?headerAction,
            ],
          ),
        ),
        Expanded(
          child: favoriteChannels.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TvLayoutConstants.viewerFavoritesBarPaddingStart,
                    0,
                    TvLayoutConstants.viewerFavoritesBarPaddingEnd,
                    0,
                  ),
                  child: Center(
                    child: Text(
                      LocaleKeys.favorites_empty.tr(),
                      textAlign: TextAlign.center,
                      style: MoaiText.body(
                        context,
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  padding: _contentPadding,
                  itemCount: favoriteChannels.length,
                  separatorBuilder: (_, _) => const SizedBox(
                    width: TvLayoutConstants.viewerFavoriteTileSpacing,
                  ),
                  itemBuilder: (context, index) {
                    final channel = favoriteChannels[index];
                    return Actions(
                      actions: <Type, Action<Intent>>{
                        DpadLeftIntent: CallbackAction<DpadLeftIntent>(
                          onInvoke: (_) {
                            if (index > 0) {
                              onFocusPrevious(index);
                            } else {
                              onFocusLeft?.call();
                            }
                            return null;
                          },
                        ),
                        DpadRightIntent: CallbackAction<DpadRightIntent>(
                          onInvoke: (_) {
                            if (index < favoriteChannels.length - 1) {
                              onFocusNext(index);
                            } else {
                              onFocusRight?.call();
                            }
                            return null;
                          },
                        ),
                        DpadUpIntent: CallbackAction<DpadUpIntent>(
                          onInvoke: (_) {
                            onKeyUp();
                            return null;
                          },
                        ),
                        DpadDownIntent: CallbackAction<DpadDownIntent>(
                          onInvoke: (_) {
                            onKeyDown();
                            return null;
                          },
                        ),
                      },
                      // La misma ficha que la grilla de canales.
                      child: SizedBox(
                        width: TvLayoutConstants.viewerFavoriteTileWidth,
                        child: ChannelGridTile(
                          key: ValueKey(channel.id),
                          channel: channel,
                          isSelected: selectedChannel?.id == channel.id,
                          focusNode: focusNodes[index],
                          onTap: () => onSelect(channel),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    // Mismo cristal que los paneles del acordeón.
    return RepaintBoundary(
      child: MoaiGlass(
        borderRadius: 16,
        solid: true,
        elevated: false,
        child: content,
      ),
    );
  }
}
