import 'package:flutter/material.dart';
import 'package:moai3/focus/focus_scroll_sync.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/models/channel.dart';

/// Scroll y foco horizontal de la barra de favoritos del visor TV.
class ViewerFavoritesController {
  final ScrollController scrollController = ScrollController();
  final List<FocusNode> focusNodes = [];

  static const _itemStride = TvLayoutConstants.viewerFavoriteTileStride;
  static const _itemVisualWidth = TvLayoutConstants.viewerFavoriteTileWidth;
  static const _scrollInset = TvLayoutConstants.viewerFavoritesBarScrollInset;

  void syncFrom(int count) {
    FocusScrollSync.syncFocusNodes(count, focusNodes);
  }

  void _focusIndex(int index, int itemCount) {
    FocusScrollSync.focusHorizontalItem(
      scrollController: scrollController,
      focusNodes: focusNodes,
      index: index,
      itemStride: _itemStride,
      itemVisualWidth: _itemVisualWidth,
      itemCount: itemCount,
      paddingStart: TvLayoutConstants.viewerFavoritesBarPaddingStart,
      paddingEnd: TvLayoutConstants.viewerFavoritesBarPaddingEnd,
      edgeInset: _scrollInset,
    );
  }

  void focusPlayingChannel(List<Channel> channels, Channel? playingChannel) {
    final totalCount = channels.isEmpty ? 0 : channels.length + 2;
    if (channels.isEmpty) {
      return;
    }

    if (playingChannel != null) {
      final idx = channels.indexWhere((c) => c.id == playingChannel.id);
      if (idx != -1) {
        _focusIndex(idx, totalCount);
        return;
      }
    }

    focusFirst();
  }

  void focusFirst() {
    FocusScrollSync.requestFocusAtIndex(focusNodes, 0);
  }

  void focusPrevious(int index) {
    if (index <= 0) return;
    _focusIndex(index - 1, focusNodes.length);
  }

  void focusNext(int index, int itemCount) {
    if (index >= itemCount - 1) return;
    _focusIndex(index + 1, itemCount);
  }

  void dispose() {
    scrollController.dispose();
    for (final node in focusNodes) {
      node.dispose();
    }
    focusNodes.clear();
  }
}

