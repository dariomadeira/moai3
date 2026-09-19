import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_input/tv_keyboard_layouts.dart';
import 'package:moai3/widgets/tv_input/tv_keyboard_type.dart';

typedef TvKeyPressed = void Function(TvKeyDef key);

class TvOnScreenKeyboard extends StatefulWidget {
  final TvKeyboardType type;
  final TvKeyPressed onKey;
  final VoidCallback onCancel;
  final VoidCallback onDone;
  final String? doneLabel;

  const TvOnScreenKeyboard({
    super.key,
    required this.type,
    required this.onKey,
    required this.onCancel,
    required this.onDone,
    this.doneLabel,
  });

  @override
  State<TvOnScreenKeyboard> createState() => _TvOnScreenKeyboardState();
}

class _TvOnScreenKeyboardState extends State<TvOnScreenKeyboard> {
  bool _shift = false;
  bool _digitsMode = false;

  List<List<FocusNode>> _nodes = const [];
  List<List<TvKeyDef>> _rows = const [];
  final FocusNode _cancelNode = FocusNode(debugLabel: 'tv_kb_cancel');
  final FocusNode _doneNode = FocusNode(debugLabel: 'tv_kb_done');

  @override
  void initState() {
    super.initState();
    _rebuildLayout(requestInitialFocus: true);
  }

  @override
  void didUpdateWidget(covariant TvOnScreenKeyboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _shift = false;
      _digitsMode = false;
      _rebuildLayout(requestInitialFocus: true);
    }
  }

  void _rebuildLayout({required bool requestInitialFocus}) {
    final oldNodes = _nodes;
    _rows = TvKeyboardLayouts.forType(
      widget.type,
      digitsMode: _digitsMode,
      shift: _shift,
    );
    _nodes = [
      for (final row in _rows)
        [
          for (var i = 0; i < row.length; i++)
            FocusNode(debugLabel: 'tv_kb_${row.length}_$i'),
        ],
    ];
    if (oldNodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final row in oldNodes) {
          for (final node in row) {
            if (node.hasFocus) node.unfocus();
            node.dispose();
          }
        }
      });
    }
    if (requestInitialFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_nodes.isNotEmpty && _nodes.first.isNotEmpty) {
          _nodes.first.first.requestFocus();
        }
      });
    }
  }

  void _disposeKeyNodes() {
    for (final row in _nodes) {
      for (final node in row) {
        node.dispose();
      }
    }
    _nodes = const [];
  }

  @override
  void dispose() {
    _disposeKeyNodes();
    _cancelNode.dispose();
    _doneNode.dispose();
    super.dispose();
  }

  void _handleKey(TvKeyDef def) {
    switch (def.action) {
      case TvKeyAction.shift:
        _shift = !_shift;
        _rebuildLabelsOnly();
        setState(() {});
        return;
      case TvKeyAction.switchDigits:
        _digitsMode = true;
        _shift = false;
        // Layout distinto (5→4 filas): recrear nodos y foco en la 1ª tecla.
        _rebuildLayout(requestInitialFocus: true);
        setState(() {});
        return;
      case TvKeyAction.switchLetters:
        _digitsMode = false;
        _rebuildLayout(requestInitialFocus: true);
        setState(() {});
        return;
      case TvKeyAction.cancel:
        widget.onCancel();
        return;
      case TvKeyAction.done:
        widget.onDone();
        return;
      default:
        widget.onKey(def);
        if (_shift && def.action == TvKeyAction.character) {
          _shift = false;
          _rebuildLabelsOnly();
          setState(() {});
        }
    }
  }

  void _rebuildLabelsOnly() {
    final next = TvKeyboardLayouts.forType(
      widget.type,
      digitsMode: _digitsMode,
      shift: _shift,
    );
    final sameShape = next.length == _rows.length &&
        List.generate(next.length, (i) => next[i].length == _rows[i].length)
            .every((v) => v);
    if (sameShape) {
      _rows = next;
      return;
    }
    _rebuildLayout(requestInitialFocus: false);
  }

  void _move({
    required int row,
    required int col,
    required int dRow,
    required int dCol,
  }) {
    if (dRow != 0) {
      final targetRow = row + dRow;
      if (targetRow < 0) return;
      if (targetRow >= _nodes.length) {
        (col <= _nodes[row].length ~/ 2 ? _cancelNode : _doneNode)
            .requestFocus();
        return;
      }
      final targetCol = col.clamp(0, _nodes[targetRow].length - 1);
      _nodes[targetRow][targetCol].requestFocus();
      return;
    }

    final targetCol = col + dCol;
    if (targetCol < 0 || targetCol >= _nodes[row].length) return;
    _nodes[row][targetCol].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = widget.type == TvKeyboardType.ip ||
        widget.type == TvKeyboardType.port ||
        widget.type == TvKeyboardType.number;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isCompact ? 248 : 500,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < _rows.length; r++) ...[
                if (r > 0) const SizedBox(height: 4),
                Row(
                  children: [
                    for (var c = 0; c < _rows[r].length; c++) ...[
                      if (c > 0) const SizedBox(width: 4),
                      Expanded(
                        flex: (_rows[r][c].flex * 100).round(),
                        child: _TvKeyButton(
                          key: ValueKey(
                            'kb_${_digitsMode}_${_shift}_${r}_${c}_'
                            '${_rows[r][c].action}_${_rows[r][c].label}',
                          ),
                          focusNode: _nodes[r][c],
                          label: _rows[r][c].label ?? '',
                          emphasized: _rows[r][c].action !=
                                  TvKeyAction.character &&
                              _rows[r][c].action != TvKeyAction.space,
                          onPressed: () => _handleKey(_rows[r][c]),
                          onArrow: (dRow, dCol) =>
                              _move(row: r, col: c, dRow: dRow, dCol: dCol),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _TvActionButton(
                focusNode: _cancelNode,
                label: 'keyboard_cancel'.tr(),
                filled: false,
                onPressed: widget.onCancel,
                onArrowLeft: () {},
                onArrowRight: () => _doneNode.requestFocus(),
                onArrowUp: () {
                  if (_nodes.isEmpty) return;
                  final last = _nodes.last;
                  last.first.requestFocus();
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: _TvActionButton(
                focusNode: _doneNode,
                label: widget.doneLabel ?? 'keyboard_done'.tr(),
                filled: true,
                onPressed: widget.onDone,
                onArrowLeft: () => _cancelNode.requestFocus(),
                onArrowRight: () {},
                onArrowUp: () {
                  if (_nodes.isEmpty) return;
                  final last = _nodes.last;
                  last.last.requestFocus();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TvKeyButton extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final bool emphasized;
  final VoidCallback onPressed;
  final void Function(int dRow, int dCol) onArrow;

  const _TvKeyButton({
    super.key,
    required this.focusNode,
    required this.label,
    required this.emphasized,
    required this.onPressed,
    required this.onArrow,
  });

  @override
  State<_TvKeyButton> createState() => _TvKeyButtonState();
}

class _TvKeyButtonState extends State<_TvKeyButton> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_syncFocus);
  }

  @override
  void didUpdateWidget(covariant _TvKeyButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_syncFocus);
      widget.focusNode.addListener(_syncFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_syncFocus);
    super.dispose();
  }

  void _syncFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focused = widget.focusNode.hasFocus;

    // Gboard M3 Expressive: letras blancas, funciones pastel azul, sin bordes.
    final Color bg;
    final Color fg;
    if (focused) {
      bg = scheme.primary;
      fg = scheme.onPrimary;
    } else if (widget.emphasized) {
      bg = scheme.primaryContainer;
      fg = scheme.onPrimaryContainer;
    } else {
      bg = scheme.surface;
      fg = scheme.onSurface;
    }

    const radius = 12.0;

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft) {
          widget.onArrow(0, -1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          widget.onArrow(0, 1);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp) {
          widget.onArrow(-1, 0);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          widget.onArrow(1, 0);
          return KeyEventResult.handled;
        }
        // Back del remoto: consumir la tecla SIN cerrar. El cierre lo hace
        // PopScope del sheet (si también hacemos pop acá, el 2º pop sale de Home).
        if (_isTvCancelKey(key)) {
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.gameButtonA) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onPressed,
          splashColor: fg.withValues(alpha: 0.12),
          highlightColor: fg.withValues(alpha: 0.08),
          child: SizedBox(
            height: 34,
            child: Center(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MoaiText.body(
                  context,
                  color: fg,
                  fontSize: widget.label.length > 2 ? 10 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TvActionButton extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final bool filled;
  final VoidCallback onPressed;
  final VoidCallback onArrowLeft;
  final VoidCallback onArrowRight;
  final VoidCallback onArrowUp;

  const _TvActionButton({
    required this.focusNode,
    required this.label,
    required this.filled,
    required this.onPressed,
    required this.onArrowLeft,
    required this.onArrowRight,
    required this.onArrowUp,
  });

  @override
  State<_TvActionButton> createState() => _TvActionButtonState();
}

class _TvActionButtonState extends State<_TvActionButton> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_syncFocus);
  }

  @override
  void didUpdateWidget(covariant _TvActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_syncFocus);
      widget.focusNode.addListener(_syncFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_syncFocus);
    super.dispose();
  }

  void _syncFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focused = widget.focusNode.hasFocus;

    // Siguiente = secondary (CTA distinto del foco primary de las teclas).
    final Color bg;
    final Color fg;
    if (focused) {
      bg = scheme.primary;
      fg = scheme.onPrimary;
    } else if (widget.filled) {
      bg = scheme.secondary;
      fg = scheme.onSecondary;
    } else {
      bg = scheme.primaryContainer;
      fg = scheme.onPrimaryContainer;
    }

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft) {
          widget.onArrowLeft();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          widget.onArrowRight();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp) {
          widget.onArrowUp();
          return KeyEventResult.handled;
        }
        // Ver comentario en _TvKeyButton: consumir Back sin pop.
        if (_isTvCancelKey(key)) {
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.gameButtonA) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: bg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onPressed,
          splashColor: fg.withValues(alpha: 0.12),
          child: SizedBox(
            height: 36,
            child: Center(
              child: Text(
                widget.label,
                style: MoaiText.body(
                  context,
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _isTvCancelKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.browserBack ||
      key == LogicalKeyboardKey.cancel;
}

