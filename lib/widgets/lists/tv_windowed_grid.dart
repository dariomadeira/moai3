import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';

/// Grilla TV por ventana fija (sin scroll continuo).
///
/// Por defecto 2 columnas × 3 filas (6 celdas). El foco se mueve con D-pad;
/// ↑/↓ desplazan de a una fila ([crossAxisCount] ítems).
class TvWindowedGrid<T> extends StatefulWidget {
  final List<T> items;
  final int crossAxisCount;
  final int windowSize;
  final int initialGlobalIndex;
  /// Alto de cada fila (tile + gap vertical).
  final double itemExtent;
  final double crossAxisSpacing;
  final TvScrollIndicator scrollIndicator;
  final bool showScrollDots;
  final bool showScrollArrows;
  final VoidCallback? onFocusUpFromFirst;
  final VoidCallback? onExitLeft;
  final VoidCallback? onExitRight;
  final ValueChanged<int>? onFocusedGlobalIndex;
  final Widget Function(
    BuildContext context,
    T item,
    FocusNode focusNode,
    int localIndex,
    int globalIndex,
    VoidCallback onKeyUp,
    VoidCallback onKeyDown,
    bool Function() onKeyLeft,
    bool Function() onKeyRight,
  ) itemBuilder;

  const TvWindowedGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.crossAxisCount = 2,
    this.windowSize = 6,
    this.initialGlobalIndex = 0,
    this.itemExtent = 96,
    this.crossAxisSpacing = 8,
    this.scrollIndicator = TvScrollIndicator.none,
    this.showScrollDots = false,
    this.showScrollArrows = false,
    this.onFocusUpFromFirst,
    this.onExitLeft,
    this.onExitRight,
    this.onFocusedGlobalIndex,
  });

  @override
  State<TvWindowedGrid<T>> createState() => TvWindowedGridState<T>();
}

class TvWindowedGridState<T> extends State<TvWindowedGrid<T>> {
  late int _windowStart;
  late int _localFocus;
  late List<FocusNode> _nodes;

  int get crossAxisCount {
    final v = widget.crossAxisCount;
    if (v < 1) return 1;
    if (v > 8) return 8;
    return v;
  }

  int get windowSize {
    final v = widget.windowSize;
    if (v < 1) return 1;
    if (v > 64) return 64;
    return v;
  }

  int get _rowCount => (windowSize / crossAxisCount).ceil();

  int get _visibleCount {
    if (widget.items.isEmpty) return 0;
    final remaining = widget.items.length - _windowStart;
    if (remaining < 0) return 0;
    if (remaining > windowSize) return windowSize;
    return remaining;
  }

  int get _activeLocal {
    for (var i = 0; i < _visibleCount; i++) {
      if (_nodes[i].hasFocus) return i;
    }
    final maxLocal = _visibleCount <= 0 ? 0 : _visibleCount - 1;
    if (_localFocus < 0) return 0;
    if (_localFocus > maxLocal) return maxLocal;
    return _localFocus;
  }

  int get focusedGlobalIndex => _windowStart + _activeLocal;

  int get pageCount =>
      widget.items.isEmpty ? 0 : (widget.items.length / windowSize).ceil();

  int get activeDotIndex => pageCount <= 1
      ? 0
      : (focusedGlobalIndex / windowSize).floor().clamp(0, pageCount - 1);

  bool get canScrollUp => _windowStart > 0;

  bool get canScrollDown {
    if (widget.items.isEmpty) return false;
    return _windowStart + windowSize < widget.items.length;
  }

  TvScrollIndicator get effectiveIndicator {
    if (widget.showScrollArrows ||
        widget.scrollIndicator == TvScrollIndicator.arrows) {
      return TvScrollIndicator.arrows;
    }
    if (widget.showScrollDots ||
        widget.scrollIndicator == TvScrollIndicator.dots) {
      return TvScrollIndicator.dots;
    }
    return TvScrollIndicator.none;
  }

  int _maxAlignedStart() {
    if (widget.items.isEmpty) return 0;
    final totalRows = (widget.items.length / crossAxisCount).ceil();
    var maxRow = totalRows - _rowCount;
    if (maxRow < 0) maxRow = 0;
    if (maxRow > totalRows) maxRow = totalRows;
    return maxRow * crossAxisCount;
  }

  int _alignStart(int start) {
    final cols = crossAxisCount;
    final maxStart = _maxAlignedStart();
    final aligned = (start ~/ cols) * cols;
    if (aligned < 0) return 0;
    if (aligned > maxStart) return maxStart;
    return aligned;
  }

  @override
  void initState() {
    super.initState();
    _nodes = List.generate(windowSize, (i) => FocusNode(debugLabel: 'grid_$i'));
    _placeWindowFor(widget.initialGlobalIndex);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestLocalFocus(_localFocus);
    });
  }

  @override
  void didUpdateWidget(covariant TvWindowedGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.windowSize != widget.windowSize ||
        oldWidget.crossAxisCount != widget.crossAxisCount) {
      for (final n in _nodes) {
        n.dispose();
      }
      _nodes =
          List.generate(windowSize, (i) => FocusNode(debugLabel: 'grid_$i'));
    }
    if (!identical(oldWidget.items, widget.items) ||
        oldWidget.items.length != widget.items.length ||
        oldWidget.initialGlobalIndex != widget.initialGlobalIndex) {
      final target = widget.items.isEmpty
          ? 0
          : widget.initialGlobalIndex.clamp(0, widget.items.length - 1);
      final inWindow =
          target >= _windowStart && target < _windowStart + _visibleCount;
      if (!inWindow || oldWidget.items.length != widget.items.length) {
        final hadFocus = _nodes.any((n) => n.hasFocus);
        _placeWindowFor(target);
        if (hadFocus) {
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) _requestLocalFocus(_localFocus);
          });
        }
      }
    }
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void ensureVisible(int globalIndex, {bool requestFocus = true}) {
    if (widget.items.isEmpty) return;
    final target = globalIndex.clamp(0, widget.items.length - 1);
    final inWindow =
        target >= _windowStart && target < _windowStart + _visibleCount;

    if (inWindow) {
      final local = target - _windowStart;
      _localFocus = local;
      if (requestFocus) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _requestLocalFocus(_localFocus);
        });
      }
      return;
    }

    final hadFocus = _nodes.any((n) => n.hasFocus);
    setState(() => _placeWindowFor(target));
    if (requestFocus || hadFocus) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestLocalFocus(_localFocus);
      });
    }
  }

  void _placeWindowFor(int globalIndex) {
    if (widget.items.isEmpty) {
      _windowStart = 0;
      _localFocus = 0;
      return;
    }
    final g = globalIndex.clamp(0, widget.items.length - 1);
    final cols = crossAxisCount;
    final row = g ~/ cols;
    final totalRows = (widget.items.length / cols).ceil();
    var maxStartRow = totalRows - _rowCount;
    if (maxStartRow < 0) maxStartRow = 0;

    var startRow = 0;
    if (row >= _rowCount) {
      startRow = row - (_rowCount - 2);
      if (startRow < 0) startRow = 0;
      if (startRow > maxStartRow) startRow = maxStartRow;
    }

    _windowStart = _alignStart(startRow * cols);
    final local = g - _windowStart;
    if (local < 0) {
      _localFocus = 0;
    } else if (local > windowSize - 1) {
      _localFocus = windowSize - 1;
    } else {
      _localFocus = local;
    }
  }

  void _requestLocalFocus(int local, [int attempts = 15]) {
    final maxLocal = _visibleCount - 1;
    if (maxLocal < 0) return;
    final clamped = local < 0 ? 0 : (local > maxLocal ? maxLocal : local);
    _localFocus = clamped;
    final node = _nodes[clamped];
    if (node.context != null) {
      node.requestFocus();
    } else if (attempts > 0) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestLocalFocus(clamped, attempts - 1);
      });
    }
    widget.onFocusedGlobalIndex?.call(_windowStart + clamped);
  }

  bool _moveLeft() {
    if (widget.items.isEmpty) return false;
    final local = _activeLocal;
    final col = local % crossAxisCount;
    if (col > 0) {
      setState(() => _localFocus = local - 1);
      _requestLocalFocus(_localFocus);
      return true;
    }
    if (widget.onExitLeft != null) {
      widget.onExitLeft!();
      return true;
    }
    return false;
  }

  bool _moveRight() {
    if (widget.items.isEmpty) return false;
    final local = _activeLocal;
    final col = local % crossAxisCount;
    final next = local + 1;
    if (col < crossAxisCount - 1 && next < _visibleCount) {
      setState(() => _localFocus = next);
      _requestLocalFocus(_localFocus);
      return true;
    }
    if (widget.onExitRight != null) {
      widget.onExitRight!();
      return true;
    }
    return false;
  }

  void _moveUp() {
    if (widget.items.isEmpty) return;
    final local = _activeLocal;
    final global = _windowStart + local;
    final cols = crossAxisCount;

    if (local >= cols) {
      setState(() => _localFocus = local - cols);
      _requestLocalFocus(_localFocus);
      return;
    }

    if (global < cols) {
      widget.onFocusUpFromFirst?.call();
      return;
    }

    final newStart = _alignStart(_windowStart - cols);
    setState(() {
      _windowStart = newStart;
      final nextLocal = global - _windowStart;
      _localFocus = nextLocal < 0
          ? 0
          : (nextLocal > windowSize - 1 ? windowSize - 1 : nextLocal);
    });
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestLocalFocus(_localFocus);
    });
  }

  void _moveDown() {
    if (widget.items.isEmpty) return;
    final local = _activeLocal;
    final global = _windowStart + local;
    final cols = crossAxisCount;
    final next = local + cols;

    if (next < _visibleCount) {
      setState(() => _localFocus = next);
      _requestLocalFocus(_localFocus);
      return;
    }

    if (global + cols >= widget.items.length) {
      final last = widget.items.length - 1;
      if (last > global) {
        final targetLocal = last - _windowStart;
        if (targetLocal >= 0 && targetLocal < _visibleCount) {
          setState(() => _localFocus = targetLocal);
          _requestLocalFocus(_localFocus);
        }
      }
      return;
    }

    final newStart = _alignStart(_windowStart + cols);
    if (newStart == _windowStart) return;
    setState(() {
      _windowStart = newStart;
      final nextLocal = global - _windowStart;
      _localFocus = nextLocal < 0
          ? 0
          : (nextLocal > windowSize - 1 ? windowSize - 1 : nextLocal);
    });
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestLocalFocus(_localFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final count = _visibleCount;
    final cols = crossAxisCount;
    final rows = (count / cols).ceil();
    final needed = rows * widget.itemExtent;

    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < rows; row++)
          SizedBox(
            height: widget.itemExtent,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < cols; col++) ...[
                  if (col > 0) SizedBox(width: widget.crossAxisSpacing),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final local = row * cols + col;
                        if (local >= count) {
                          return const SizedBox.shrink();
                        }
                        return widget.itemBuilder(
                          context,
                          widget.items[_windowStart + local],
                          _nodes[local],
                          local,
                          _windowStart + local,
                          _moveUp,
                          _moveDown,
                          _moveLeft,
                          _moveRight,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );

    Widget content = grid;

    if (effectiveIndicator == TvScrollIndicator.arrows) {
      final scheme = Theme.of(context).colorScheme;
      content = Stack(
        alignment: Alignment.center,
        children: [
          grid,
          if (canScrollUp)
            Positioned(
              top: 4,
              child: IgnorePointer(
                child: _buildArrowPill(context, scheme, isUp: true),
              ),
            ),
          if (canScrollDown)
            Positioned(
              bottom: 4,
              child: IgnorePointer(
                child: _buildArrowPill(context, scheme, isUp: false),
              ),
            ),
        ],
      );
    } else if (effectiveIndicator == TvScrollIndicator.dots && pageCount > 1) {
      final scheme = Theme.of(context).colorScheme;
      final activeDot = activeDotIndex;

      content = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: grid),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pageCount, (dotIdx) {
                final isActive = dotIdx == activeDot;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(vertical: 2.5),
                  width: 5.0,
                  height: 5.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? scheme.primary : scheme.outlineVariant,
                  ),
                );
              }),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        if (!maxH.isFinite || maxH >= needed) {
          return content;
        }
        return SizedBox(
          height: maxH,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.bottomCenter,
              minHeight: needed,
              maxHeight: needed,
              child: content,
            ),
          ),
        );
      },
    );
  }

  Widget _buildArrowPill(
    BuildContext context,
    ColorScheme scheme, {
    required bool isUp,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: AppIcon(
        icon: isUp ? AppIcons.arrowUp : AppIcons.arrowDown,
        size: 16,
        color: scheme.onTertiaryContainer,
      ),
    );
  }
}
