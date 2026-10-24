import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Tipo de indicador de scroll para listas TV por ventana.
enum TvScrollIndicator { none, dots, arrows }

/// Lista TV por ventana fija (sin ListView/scroll).
///
/// ↓ en el último slot: `windowStart = global - 1` → foco en slot 1.
/// ↑ en el primer slot: deja el ítem en slot `windowSize - 2`.
class TvWindowedList<T> extends StatefulWidget {
  final List<T> items;
  final int windowSize;
  final int initialGlobalIndex;
  final double itemExtent;

  /// Estilo del indicador visual de scroll.
  final TvScrollIndicator scrollIndicator;

  /// Si es true, renderiza del lado derecho unos puntos indicadores (dots)
  /// que reflejan la página o grupo de scroll actual en listas paginadas.
  final bool showScrollDots;

  /// Si es true, renderiza flechas tipo 'pill' (cápsula) superpuestas arriba o abajo
  /// según haya más elementos disponibles para hacer scroll.
  final bool showScrollArrows;
  final VoidCallback? onFocusUpFromFirst;
  final VoidCallback? onFocusDownFromLast;
  final ValueChanged<int>? onFocusedGlobalIndex;

  /// Si es false, no toma el foco al montarse (el rail lo conserva hasta →).
  final bool focusOnMount;
  final Widget Function(
    BuildContext context,
    T item,
    FocusNode focusNode,
    int localIndex,
    int globalIndex,
    VoidCallback onKeyUp,
    VoidCallback onKeyDown,
  )
  itemBuilder;

  const TvWindowedList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.windowSize = 6,
    this.initialGlobalIndex = 0,
    this.itemExtent = 56,
    this.scrollIndicator = TvScrollIndicator.none,
    this.showScrollDots = false,
    this.showScrollArrows = false,
    this.onFocusUpFromFirst,
    this.onFocusDownFromLast,
    this.onFocusedGlobalIndex,
    this.focusOnMount = true,
  });

  @override
  State<TvWindowedList<T>> createState() => TvWindowedListState<T>();
}

class TvWindowedListState<T> extends State<TvWindowedList<T>> {
  late int _windowStart;
  late int _localFocus;
  late List<FocusNode> _nodes;

  int get windowSize => widget.windowSize.clamp(1, 64);

  int get _visibleCount {
    if (widget.items.isEmpty) return 0;
    final remaining = widget.items.length - _windowStart;
    return remaining.clamp(0, windowSize);
  }

  int get _activeLocal {
    for (var i = 0; i < _visibleCount; i++) {
      final global = _windowStart + i;
      if (global < _nodes.length && _nodes[global].hasFocus) return i;
    }
    return _localFocus.clamp(0, (_visibleCount - 1).clamp(0, windowSize));
  }

  int get focusedGlobalIndex => _windowStart + _activeLocal;

  /// Cantidad total de páginas o grupos de scroll
  int get pageCount =>
      widget.items.isEmpty ? 0 : (widget.items.length / windowSize).ceil();

  /// Índice del punto / página actualmente enfocado (0-indexed)
  int get activeDotIndex => pageCount <= 1
      ? 0
      : (focusedGlobalIndex / windowSize).floor().clamp(0, pageCount - 1);

  /// Indicador efectivo a renderizar (prioriza arrows si se activó)
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

  /// Indica si hay ítems más arriba del corte visible
  bool get canScrollUp => _windowStart > 0;

  /// Indica si hay ítems más abajo del corte visible
  bool get canScrollDown =>
      widget.items.isNotEmpty &&
      (_windowStart + _visibleCount < widget.items.length);

  FocusNode _nodeFor(int global) => _nodes[global];

  /// Un nodo por ítem, no por hueco visible. Si el nodo fuera del hueco,
  /// al correr la ventana el Switch reutiliza el estado de otro ajuste.
  void _syncNodes() {
    final needed = widget.items.length;
    if (_nodes.length > needed) {
      for (final node in _nodes.sublist(needed)) {
        node.dispose();
      }
      _nodes.removeRange(needed, _nodes.length);
    }
    while (_nodes.length < needed) {
      _nodes.add(FocusNode(debugLabel: 'win_${_nodes.length}'));
    }
  }

  @override
  void initState() {
    super.initState();
    _nodes = [];
    _syncNodes();
    _placeWindowFor(widget.initialGlobalIndex, preferAnchorSlot: false);
    if (widget.focusOnMount) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestLocalFocus(_localFocus);
      });
    }
  }

  @override
  void didUpdateWidget(covariant TvWindowedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _syncNodes();
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
        _placeWindowFor(target, preferAnchorSlot: target > 0);
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

  /// Enfoca un índice global (rail / alfabeto / selectedCountry).
  void ensureVisible(int globalIndex, {bool requestFocus = true}) {
    if (widget.items.isEmpty) return;
    final target = globalIndex.clamp(0, widget.items.length - 1);
    final inWindow =
        target >= _windowStart && target < _windowStart + _visibleCount;

    if (inWindow) {
      final local = target - _windowStart;
      _localFocus = local;
      if (requestFocus) {
        _requestLocalFocus(_localFocus);
      }
      return;
    }

    final hadFocus = _nodes.any((n) => n.hasFocus);
    setState(() {
      _placeWindowFor(target, preferAnchorSlot: target > 0);
    });
    if (requestFocus || hadFocus) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestLocalFocus(_localFocus);
      });
    }
  }

  void _placeWindowFor(int globalIndex, {required bool preferAnchorSlot}) {
    if (widget.items.isEmpty) {
      _windowStart = 0;
      _localFocus = 0;
      return;
    }
    final g = globalIndex.clamp(0, widget.items.length - 1);
    final maxStart = (widget.items.length - windowSize).clamp(
      0,
      widget.items.length,
    );

    if (!preferAnchorSlot || g == 0) {
      if (g < windowSize) {
        _windowStart = 0;
        _localFocus = g;
      } else {
        _windowStart = (g - 1).clamp(0, maxStart);
        _localFocus = g - _windowStart;
      }
      return;
    }

    _windowStart = (g - 1).clamp(0, maxStart);
    _localFocus = g - _windowStart;
    if (_localFocus < 0 || _localFocus >= windowSize) {
      _windowStart = (g - windowSize + 1).clamp(0, maxStart);
      _localFocus = g - _windowStart;
    }
  }

  void _requestLocalFocus(int local, [int attempts = 15]) {
    final maxLocal = _visibleCount - 1;
    if (maxLocal < 0) return;
    final clamped = local.clamp(0, maxLocal);
    _localFocus = clamped;
    final global = _windowStart + clamped;
    if (global < 0 || global >= _nodes.length) return;
    final node = _nodeFor(global);
    if (node.context != null) {
      node.requestFocus();
    } else if (attempts > 0) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestLocalFocus(clamped, attempts - 1);
      });
    }
    widget.onFocusedGlobalIndex?.call(_windowStart + clamped);
  }

  void _moveUp() {
    if (widget.items.isEmpty) return;
    final local = _activeLocal;
    final global = _windowStart + local;

    if (local > 0) {
      setState(() => _localFocus = local - 1);
      _requestLocalFocus(_localFocus);
      return;
    }

    if (global <= 0) {
      widget.onFocusUpFromFirst?.call();
      return;
    }

    final anchorSlot = (windowSize - 2).clamp(0, windowSize - 1);
    final maxStart = (widget.items.length - windowSize).clamp(
      0,
      widget.items.length,
    );
    final newStart = (global - anchorSlot).clamp(0, maxStart);
    setState(() {
      _windowStart = newStart;
      _localFocus = global - _windowStart;
    });
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestLocalFocus(_localFocus);
    });
  }

  void _moveDown() {
    if (widget.items.isEmpty) return;
    final local = _activeLocal;
    final global = _windowStart + local;
    final lastLocal = _visibleCount - 1;

    if (local < lastLocal) {
      setState(() => _localFocus = local + 1);
      _requestLocalFocus(_localFocus);
      return;
    }

    if (global >= widget.items.length - 1) {
      widget.onFocusDownFromLast?.call();
      return;
    }

    final maxStart = (widget.items.length - windowSize).clamp(
      0,
      widget.items.length,
    );
    final newStart = (global - 1).clamp(0, maxStart);
    setState(() {
      _windowStart = newStart;
      _localFocus = global - _windowStart;
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
    final needed = count * widget.itemExtent;

    final list = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var local = 0; local < count; local++)
          SizedBox(
            key: ValueKey<int>(_windowStart + local),
            height: widget.itemExtent,
            child: widget.itemBuilder(
              context,
              widget.items[_windowStart + local],
              _nodeFor(_windowStart + local),
              local,
              _windowStart + local,
              _moveUp,
              _moveDown,
            ),
          ),
      ],
    );

    Widget content = list;

    if (effectiveIndicator == TvScrollIndicator.arrows) {
      final scheme = Theme.of(context).colorScheme;
      content = Stack(
        alignment: Alignment.center,
        children: [
          list,
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
        children: [
          Expanded(child: list),
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

    // Si el padre aprieta el alto (p. ej. animación del acordeón), no assert:
    // clip sin cambiar itemExtent ni el anclaje visual inferior.
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
      child: Icon(
        isUp ? MoaiIcons.chevronUp : MoaiIcons.chevronDown,
        size: MoaiIconSizes.sm,
        color: scheme.onTertiaryContainer,
      ),
    );
  }
}
