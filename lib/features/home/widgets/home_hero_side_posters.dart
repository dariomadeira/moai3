import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/home/widgets/tv_movie_card.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/models/movie_models.dart';

/// Los pósters a la derecha de la tarjeta grande de la fila destacada del
/// Inicio: del alto de la fila y con el ancho que les da el afiche.
///
/// Como la grilla de Películas, tienen un único [focusNode]: el póster
/// elegido es un índice y las tarjetas sólo lo dibujan. ←/→ pasan de uno a
/// otro; ← desde el primero llama a [onExitLeft]; OK abre ([onOpen]).
class HomeHeroSidePosters extends StatefulWidget {
  const HomeHeroSidePosters({
    super.key,
    required this.items,
    required this.focusNode,
    required this.onOpen,
    this.onExitLeft,
    this.onExitUp,
    this.onExitDown,
    this.gap = 12,
  });

  final List<MovieItem> items;
  final FocusNode focusNode;
  final ValueChanged<MovieItem> onOpen;
  final VoidCallback? onExitLeft;
  final VoidCallback? onExitUp;
  final VoidCallback? onExitDown;

  /// Antes de cada póster.
  final double gap;

  /// Ancho que ocupan [count] pósters de alto [height], con sus separaciones.
  static double widthFor(int count, double height, {double gap = 12}) =>
      count * (gap + TvMovieCard.widthForHeight(height));

  @override
  State<HomeHeroSidePosters> createState() => HomeHeroSidePostersState();
}

class HomeHeroSidePostersState extends State<HomeHeroSidePosters> {
  int _index = 0;

  @visibleForTesting
  int get debugIndex => _index;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant HomeHeroSidePosters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
    if (_index >= widget.items.length) _index = 0;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (widget.items.isEmpty) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (repeat) return KeyEventResult.handled;
      if (_index > 0) {
        setState(() => _index--);
      } else {
        widget.onExitLeft?.call();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      // Después del último no hay nada.
      if (!repeat && _index < widget.items.length - 1) {
        setState(() => _index++);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (widget.onExitUp == null) return KeyEventResult.ignored;
      widget.onExitUp!();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (widget.onExitDown == null) return KeyEventResult.ignored;
      widget.onExitDown!();
      return KeyEventResult.handled;
    }
    if (!repeat && TvKeyHandler.isActionKey(key)) {
      widget.onOpen(widget.items[_index]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _onKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = TvMovieCard.widthForHeight(constraints.maxHeight);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.items.length; i++) ...[
                SizedBox(width: widget.gap),
                SizedBox(
                  width: width,
                  child: RepaintBoundary(
                    child: TvMovieCard(
                      key: ValueKey('hero_side_${widget.items[i].contentId}'),
                      movie: widget.items[i],
                      isSelected: focused && _index == i,
                      onTap: () {
                        setState(() => _index = i);
                        widget.focusNode.requestFocus();
                        widget.onOpen(widget.items[i]);
                      },
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
