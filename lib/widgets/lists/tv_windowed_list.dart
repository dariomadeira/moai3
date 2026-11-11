import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

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

  /// Cuántos lugares de la ventana ocupa cada ítem (sin esto, uno; como
  /// mucho [windowSize]). Un ítem de 2 mide el doble de [itemExtent].
  final int Function(T item)? itemSpan;

  /// Por páginas fijas: la ventana no se corre de a un ítem sino de a una
  /// página (llenas en orden, de a [windowSize] lugares). ↓ desde el último
  /// de una página pasa a la siguiente entera, ↑ a la anterior. Lo que no
  /// llena la página queda abajo, nunca centrado, y hay un punto por
  /// página. Para que todas salgan llenas, quien arma [items] los ordena.
  final bool paged;

  /// Si el ítem toma el foco (sin esto, todos). ↑/↓ saltean los que no
  /// (p. ej. una tarjeta que sólo informa), pero se siguen viendo.
  final bool Function(T item)? canFocus;
  final VoidCallback? onFocusUpFromFirst;
  final VoidCallback? onFocusDownFromLast;
  final ValueChanged<int>? onFocusedGlobalIndex;

  /// Si es false, no toma el foco al montarse (el rail lo conserva hasta →).
  final bool focusOnMount;

  /// Alto del lugar de cada flecha (arriba y abajo) con
  /// [TvScrollIndicator.arrows]: quien da el alto de la lista lo suma dos
  /// veces.
  static const double arrowAreaHeight = 22;
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
    this.itemSpan,
    this.paged = false,
    this.canFocus,
    this.onFocusUpFromFirst,
    this.onFocusDownFromLast,
    this.onFocusedGlobalIndex,
    this.focusOnMount = true,
  });

  /// Ordena [items] para [paged]: en el orden dado, pero sin dejar huecos.
  /// Si en la página queda menos lugar del que ocupa el siguiente, se
  /// adelanta el próximo que entre; si no hay ninguno, el último más chico
  /// de la página baja a la siguiente (después del que no entraba). Así
  /// todas las páginas salen llenas salvo, si sobra, la última.
  static List<T> packPages<T>(
    List<T> items, {
    required int pageSize,
    required int Function(T item) span,
  }) {
    int spanOf(T item) => span(item).clamp(1, pageSize);
    final pending = [...items];
    final pages = <List<T>>[[]];
    var free = pageSize;
    while (pending.isNotEmpty) {
      if (free == 0) {
        pages.add([]);
        free = pageSize;
      }
      final next = pending.indexWhere((item) => spanOf(item) <= free);
      if (next >= 0) {
        final item = pending.removeAt(next);
        pages.last.add(item);
        free -= spanOf(item);
        continue;
      }
      final needed = spanOf(pending.first);
      final page = pages.last;
      final down = page.lastIndexWhere(
        (item) => spanOf(item) < needed && spanOf(item) + free >= needed,
      );
      if (down < 0) {
        // No hay cómo llenarla: queda con hueco.
        pages.add([]);
        free = pageSize;
        continue;
      }
      final moved = page.removeAt(down);
      free += spanOf(moved);
      pending.insert(1, moved);
    }
    return [for (final page in pages) ...page];
  }

  @override
  State<TvWindowedList<T>> createState() => TvWindowedListState<T>();
}

class TvWindowedListState<T> extends State<TvWindowedList<T>> {
  late int _windowStart;
  late int _localFocus;
  late List<FocusNode> _nodes;

  int get windowSize => widget.windowSize.clamp(1, 64);

  int get _visibleCount => _countFrom(_windowStart);

  /// Lugares que ocupa el ítem [global].
  int _span(int global) =>
      (widget.itemSpan?.call(widget.items[global]) ?? 1).clamp(1, windowSize);

  /// Cuántos ítems entran en la ventana empezando en [start] (al menos uno).
  int _countFrom(int start) {
    var slots = 0;
    var count = 0;
    for (var g = start; g < widget.items.length; g++) {
      slots += _span(g);
      if (slots > windowSize && count > 0) break;
      count++;
      if (slots >= windowSize) break;
    }
    return count;
  }

  /// Primer ítem de la ventana más baja posible (la que muestra el último).
  int get _maxStart {
    var start = widget.items.length;
    var slots = 0;
    while (start > 0 && slots + _span(start - 1) <= windowSize) {
      slots += _span(start - 1);
      start--;
    }
    return start;
  }

  /// Primer ítem de cada página ([TvWindowedList.paged]), en orden.
  List<int> get _pageStarts {
    final starts = <int>[];
    for (var g = 0; g < widget.items.length; g += _countFrom(g)) {
      starts.add(g);
    }
    return starts;
  }

  /// Página de [global] ([TvWindowedList.paged]).
  int _pageOf(int global) =>
      _pageStarts.lastIndexWhere((start) => start <= global).clamp(0, 1 << 20);

  /// [start] corrido hacia abajo lo justo para que se vea [global] (con
  /// ítems de varios lugares puede no entrar). Por páginas, la página de
  /// [global] entera.
  int _fit(int start, int global) {
    if (widget.paged) return _pageStarts[_pageOf(global)];
    var s = start.clamp(0, _maxStart);
    while (s < global && global >= s + _countFrom(s)) {
      s++;
    }
    return s;
  }

  bool _focusable(int global) =>
      widget.canFocus?.call(widget.items[global]) ?? true;

  /// El primero que toma el foco desde [from] yendo de a [step] (±1); -1 si
  /// no hay.
  int _nextFocusable(int from, int step) {
    for (var g = from; g >= 0 && g < widget.items.length; g += step) {
      if (_focusable(g)) return g;
    }
    return -1;
  }

  /// [global] o, si no toma el foco, el más cercano que sí (primero hacia
  /// abajo); el mismo [global] si no hay ninguno.
  int _focusableNear(int global) {
    if (_focusable(global)) return global;
    final down = _nextFocusable(global + 1, 1);
    if (down >= 0) return down;
    final up = _nextFocusable(global - 1, -1);
    return up >= 0 ? up : global;
  }

  /// Enfoca [target] salteando ítems sin foco: si no se ve, la ventana
  /// arranca en [start] (o lo justo para que se vea).
  void _jumpTo(int target, int start) {
    if (target >= _windowStart && target < _windowStart + _visibleCount) {
      setState(() => _localFocus = target - _windowStart);
      _requestLocalFocus(_localFocus);
      return;
    }
    setState(() {
      _windowStart = _fit(start, target);
      _localFocus = target - _windowStart;
    });
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestLocalFocus(_localFocus);
    });
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
  int get pageCount => widget.items.isEmpty
      ? 0
      : widget.paged
      ? _pageStarts.length
      : (widget.items.length / windowSize).ceil();

  /// Índice del punto / página actualmente enfocado (0-indexed)
  int get activeDotIndex => pageCount <= 1
      ? 0
      : widget.paged
      ? _pageOf(_windowStart)
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
    // Cambió cuántos entran (p. ej. el alto del panel): se vuelve a ubicar
    // la ventana sobre el ítem con foco para que no quede afuera.
    if (oldWidget.windowSize != widget.windowSize && widget.items.isNotEmpty) {
      final hadFocus = _nodes.any((n) => n.hasFocus);
      final focused = (_windowStart + _localFocus).clamp(
        0,
        widget.items.length - 1,
      );
      _placeWindowFor(focused, preferAnchorSlot: false);
      if (hadFocus) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _requestLocalFocus(_localFocus);
        });
      }
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
    final target = _focusableNear(
      globalIndex.clamp(0, widget.items.length - 1),
    );
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
    final g = _focusableNear(globalIndex.clamp(0, widget.items.length - 1));

    if (!preferAnchorSlot || g == 0) {
      _windowStart = g < windowSize ? _fit(0, g) : _fit(g - 1, g);
      _localFocus = g - _windowStart;
      return;
    }

    _windowStart = _fit(g - 1, g);
    _localFocus = g - _windowStart;
  }

  void _requestLocalFocus(int local, [int attempts = 15]) {
    final maxLocal = _visibleCount - 1;
    if (maxLocal < 0) return;
    final clamped = local.clamp(0, maxLocal);
    _localFocus = clamped;
    final global = _windowStart + clamped;
    if (global < 0 || global >= _nodes.length) return;
    final node = _nodeFor(global);
    if (node.context != null && node.canRequestFocus) {
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

    final previous = _nextFocusable(global - 1, -1);
    if (previous < 0) {
      widget.onFocusUpFromFirst?.call();
      return;
    }
    if (previous != global - 1) {
      _jumpTo(previous, previous);
      return;
    }

    if (local > 0) {
      setState(() => _localFocus = local - 1);
      _requestLocalFocus(_localFocus);
      return;
    }

    // Por páginas: al último de la anterior, con su página entera.
    if (widget.paged) {
      _jumpTo(previous, previous);
      return;
    }

    if (global <= 0) {
      widget.onFocusUpFromFirst?.call();
      return;
    }

    final anchorSlot = (windowSize - 2).clamp(0, windowSize - 1);
    var newStart = _fit(global - anchorSlot, global);
    var target = global;
    if (newStart == _windowStart) {
      // Como en [_moveDown]: si la ventana no se puede correr dejando a la
      // vista el enfocado (ventana de dos), pasa directo al anterior; si no
      // ↑ quedaría trabado.
      newStart = _fit(previous - anchorSlot, previous);
      target = previous;
    }
    setState(() {
      _windowStart = newStart;
      _localFocus = target - _windowStart;
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

    final next = _nextFocusable(global + 1, 1);
    if (next < 0) {
      widget.onFocusDownFromLast?.call();
      return;
    }
    if (next != global + 1) {
      _jumpTo(next, next - 1);
      return;
    }

    if (local < lastLocal) {
      setState(() => _localFocus = local + 1);
      _requestLocalFocus(_localFocus);
      return;
    }

    if (global >= widget.items.length - 1) {
      widget.onFocusDownFromLast?.call();
      return;
    }

    var newStart = _fit(global - 1, global);
    var target = global;
    if (newStart == _windowStart) {
      // Con ítems de varios lugares (dos grandes seguidos) la ventana no se
      // puede correr dejando a la vista el enfocado: pasa directo al
      // siguiente, si no ↓ quedaría trabado.
      newStart = _fit(next - 1, next);
      target = next;
    }
    setState(() {
      _windowStart = newStart;
      _localFocus = target - _windowStart;
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
    final arrows = effectiveIndicator == TvScrollIndicator.arrows;
    var slots = 0;
    for (var local = 0; local < count; local++) {
      slots += _span(_windowStart + local);
    }
    final needed =
        slots * widget.itemExtent +
        (arrows ? 2 * TvWindowedList.arrowAreaHeight : 0);

    final list = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var local = 0; local < count; local++)
          SizedBox(
            key: ValueKey<int>(_windowStart + local),
            height: widget.itemExtent * _span(_windowStart + local),
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

    if (arrows) {
      // Las flechas van en su propio lugar arriba y abajo, nunca encima de
      // los ítems (como en la grilla semanal de Agenda y Descuentos).
      final scheme = Theme.of(context).colorScheme;
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: TvWindowedList.arrowAreaHeight,
            child: canScrollUp
                ? _buildArrowPill(context, scheme, isUp: true)
                : null,
          ),
          list,
          SizedBox(
            height: TvWindowedList.arrowAreaHeight,
            child: canScrollDown
                ? _buildArrowPill(context, scheme, isUp: false)
                : null,
          ),
        ],
      );
    } else if (effectiveIndicator == TvScrollIndicator.dots && pageCount > 1) {
      final scheme = Theme.of(context).colorScheme;
      final activeDot = activeDotIndex;

      content = Row(
        children: [
          // Por páginas, la que no se llena queda arriba (el hueco abajo,
          // donde se entiende que termina); los puntos, centrados.
          Expanded(
            child: widget.paged
                ? Align(alignment: Alignment.topCenter, child: list)
                : list,
          ),
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
                  // Como en [TvWindowedRow]: el de la página actual se
                  // estira (acá hacia abajo), se lee de lejos.
                  height: isActive ? 5.0 * 2.4 : 5.0,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5.0),
                    // Los otros, gris medio: sobre el cristal claro se ven
                    // (casi blancos se perdían).
                    color: isActive
                        ? scheme.primary
                        : scheme.onSurface.withValues(alpha: 0.3),
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
    // El mismo chip que las flechas de la grilla semanal.
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: moaiGlassChipDecoration(scheme, highlighted: true),
        child: Icon(
          isUp ? MoaiIcons.chevronUp : MoaiIcons.chevronDown,
          size: MoaiIconSizes.xs,
          color: scheme.primary,
        ),
      ),
    );
  }
}
