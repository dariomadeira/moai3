import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/settings/widgets/tv_option_selector.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';

/// Fila de ajustes con opciones (selector tipo píldora) y modo edición.
///
/// - Sin editar: ← → cambian de panel como cualquier fila; OK entra a editar.
/// - Editando: ← → cambian la opción; OK o Atrás salen. ↑ ↓ salen y se mueven.
class SettingsOptionRow<T> extends StatefulWidget {
  const SettingsOptionRow({
    super.key,
    required this.focusNode,
    required this.label,
    required this.icon,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.labelBuilder,
    this.description,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  final FocusNode focusNode;
  final String label;
  final String? description;
  final IconData icon;
  final List<T> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T option) labelBuilder;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  @override
  State<SettingsOptionRow<T>> createState() => _SettingsOptionRowState<T>();
}

class _SettingsOptionRowState<T> extends State<SettingsOptionRow<T>> {
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant SettingsOptionRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChange);
      widget.focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus && _editing) {
      setState(() => _editing = false);
    }
  }

  void _setEditing(bool value) {
    if (_editing != value) setState(() => _editing = value);
  }

  void _step(int delta) {
    final options = widget.options;
    final current = options.indexOf(widget.selected);
    final next = (current < 0 ? 0 : current) + delta;
    if (next < 0 || next >= options.length) return;
    widget.onChanged(options[next]);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!_editing) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowLeft) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    if (TvKeyHandler.isActionKey(key) ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape) {
      _setEditing(false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      // Sale de editar y deja que la fila mueva el foco.
      _setEditing(false);
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return TvTile(
      focusNode: widget.focusNode,
      label: widget.label,
      description: widget.description,
      icon: widget.icon,
      onPressed: () => _setEditing(true),
      onKeyLeft: widget.onKeyLeft,
      onKeyRight: widget.onKeyRight,
      onKeyUp: widget.onKeyUp,
      onKeyDown: widget.onKeyDown,
      onKeyEvent: _onKeyEvent,
      trailingBuilder: (context, isFocused) => TvOptionSelector<T>(
        options: widget.options,
        selectedValue: widget.selected,
        onSelect: widget.onChanged,
        labelBuilder: widget.labelBuilder,
        isFocused: isFocused,
        // En cristal `isFocused` llega en false (la ficha no se rellena), así
        // que la edición se decide por el foco real de la fila.
        isEditing: _editing && widget.focusNode.hasFocus,
      ),
    );
  }
}
