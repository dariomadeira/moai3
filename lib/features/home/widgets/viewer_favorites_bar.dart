import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/viewer_favorite_tile.dart';
import 'package:moai3/focus/tv_intents.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/theme/moai_text.dart';

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

  static const _contentPadding = EdgeInsets.fromLTRB(
    TvLayoutConstants.viewerFavoritesBarPaddingStart,
    8,
    TvLayoutConstants.viewerFavoritesBarPaddingEnd,
    8,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(
          left: TvLayoutConstants.viewerHorizontalPaddingStart,
          right: TvLayoutConstants.viewerHorizontalPaddingEnd,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 10, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'home_tv_favorites'.tr(),
                        style: MoaiText.display(
                          context,
                          color: scheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    ?headerAction,
                  ],
                ),
              ),
              SizedBox(
                height: TvLayoutConstants.viewerFavoritesBarHeight,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14),
                  ),
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
                              'favorites_empty'.tr(),
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
                              DpadRightIntent:
                                  CallbackAction<DpadRightIntent>(
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
                            child: ViewerFavoriteTile(
                              key: ValueKey(channel.id),
                              channel: channel,
                              isSelected: selectedChannel?.id == channel.id,
                              focusNode: focusNodes[index],
                              onTap: () => onSelect(channel),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}


