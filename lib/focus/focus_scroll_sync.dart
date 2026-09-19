import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Sincroniza [FocusNode]s con listas y scroll automático.
abstract final class FocusScrollSync {
  static void syncFocusNodes(int targetCount, List<FocusNode> nodesList) {
    while (nodesList.length > targetCount) {
      nodesList.removeLast().dispose();
    }
    while (nodesList.length < targetCount) {
      nodesList.add(FocusNode());
    }
  }

  static void scrollToIndex({
    required ScrollController controller,
    required int index,
    required double itemHeight,
    required int itemCount,
    Duration duration = const Duration(milliseconds: 250),
    bool instant = false,
  }) {
    if (!controller.hasClients || index < 0) return;

    final targetOffset = index * itemHeight;
    var shouldScroll = true;
    var viewportHeight = 500.0;

    if (controller.position.hasPixels) {
      viewportHeight = controller.position.viewportDimension;
      if (viewportHeight <= 0) viewportHeight = 500.0;
      if ((controller.offset - targetOffset).abs() <= 1.0) {
        shouldScroll = false;
      }
    }

    if (shouldScroll) {
      final maxExtent = (itemCount * itemHeight - viewportHeight)
          .clamp(0.0, double.infinity);
      final clamped = targetOffset.clamp(0.0, maxExtent);
      // jumpTo: el ítem debe existir en el árbol YA para que el FocusNode
      // tenga context. animateTo deja el foco en el limbo ~250ms.
      if (instant) {
        controller.jumpTo(clamped);
      } else {
        controller.animateTo(
          clamped,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  static void requestFocusAtIndex(
    List<FocusNode> nodes,
    int index, {
    VoidCallback? onMissing,
    int retryCount = 0,
  }) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (index < 0 || index >= nodes.length) {
        onMissing?.call();
        return;
      }
      final node = nodes[index];
      // ListView.builder solo monta visibles; tras jump/acordeón puede
      // faltar context unos frames.
      if (node.context == null) {
        if (retryCount < 40) {
          requestFocusAtIndex(
            nodes,
            index,
            onMissing: onMissing,
            retryCount: retryCount + 1,
          );
        } else {
          onMissing?.call();
        }
        return;
      }
      node.requestFocus();
      // hasFocus no es síncrono: verificar en el PRÓXIMO frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (node.hasFocus) return;
        if (retryCount < 40) {
          requestFocusAtIndex(
            nodes,
            index,
            onMissing: onMissing,
            retryCount: retryCount + 1,
          );
        } else {
          onMissing?.call();
        }
      });
    });
  }

  static void focusListItem({
    required ScrollController scrollController,
    required List<FocusNode> focusNodes,
    required int index,
    required double itemHeight,
    required int itemCount,
    VoidCallback? onMissing,
    int retryCount = 0,
  }) {
    if (index < 0) {
      onMissing?.call();
      return;
    }

    if (!scrollController.hasClients) {
      if (retryCount < 40) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          focusListItem(
            scrollController: scrollController,
            focusNodes: focusNodes,
            index: index,
            itemHeight: itemHeight,
            itemCount: itemCount,
            onMissing: onMissing,
            retryCount: retryCount + 1,
          );
        });
      } else {
        onMissing?.call();
      }
      return;
    }

    scrollToIndex(
      controller: scrollController,
      index: index,
      itemHeight: itemHeight,
      itemCount: itemCount,
      instant: true,
    );
    requestFocusAtIndex(focusNodes, index, onMissing: onMissing);
  }

  static void scrollToHorizontalIndex({
    required ScrollController controller,
    required int index,
    required double itemStride,
    required double itemVisualWidth,
    required int itemCount,
    double paddingStart = 0,
    double paddingEnd = 0,
    double edgeInset = 0,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    if (!controller.hasClients || index < 0) return;

    var viewportWidth = 500.0;
    if (controller.position.hasPixels) {
      viewportWidth = controller.position.viewportDimension;
      if (viewportWidth <= 0) viewportWidth = 500.0;
    }

    if (index == 0) {
      if (controller.offset > 1.0) {
        controller.animateTo(
          0,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    if (index == itemCount - 1) {
      final maxExtent = controller.position.maxScrollExtent;
      if ((controller.offset - maxExtent).abs() > 1.0) {
        controller.animateTo(
          maxExtent,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    final itemStart = paddingStart + index * itemStride;
    final itemEnd = itemStart + itemVisualWidth;
    final viewStart = controller.offset;
    final viewEnd = viewStart + viewportWidth;

    double? targetOffset;
    if (itemStart < viewStart + edgeInset) {
      targetOffset = itemStart - edgeInset;
    } else if (itemEnd > viewEnd - edgeInset) {
      targetOffset = itemEnd - viewportWidth + edgeInset;
    }

    if (targetOffset == null) return;

    if (controller.position.hasPixels &&
        (controller.offset - targetOffset).abs() <= 1.0) {
      return;
    }

    final maxExtent = controller.position.maxScrollExtent;
    controller.animateTo(
      targetOffset.clamp(0.0, maxExtent),
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  static void focusHorizontalItem({
    required ScrollController scrollController,
    required List<FocusNode> focusNodes,
    required int index,
    required double itemStride,
    required double itemVisualWidth,
    required int itemCount,
    double paddingStart = 0,
    double paddingEnd = 0,
    double edgeInset = 0,
    VoidCallback? onMissing,
    int retryCount = 0,
  }) {
    if (index < 0) {
      onMissing?.call();
      return;
    }

    if (!scrollController.hasClients) {
      if (retryCount < 30) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          focusHorizontalItem(
            scrollController: scrollController,
            focusNodes: focusNodes,
            index: index,
            itemStride: itemStride,
            itemVisualWidth: itemVisualWidth,
            itemCount: itemCount,
            paddingStart: paddingStart,
            paddingEnd: paddingEnd,
            edgeInset: edgeInset,
            onMissing: onMissing,
            retryCount: retryCount + 1,
          );
        });
      } else {
        onMissing?.call();
      }
      return;
    }

    scrollToHorizontalIndex(
      controller: scrollController,
      index: index,
      itemStride: itemStride,
      itemVisualWidth: itemVisualWidth,
      itemCount: itemCount,
      paddingStart: paddingStart,
      paddingEnd: paddingEnd,
      edgeInset: edgeInset,
    );
    requestFocusAtIndex(focusNodes, index, onMissing: onMissing);
  }
}

