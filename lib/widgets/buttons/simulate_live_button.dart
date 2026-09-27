import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/theme/moai_text.dart';

class SimulateLiveButton extends StatefulWidget {
  final FocusNode focusNode;
  final int eventCount;
  final IconData icon;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const SimulateLiveButton({
    super.key,
    required this.focusNode,
    this.eventCount = 1,
    this.icon = Icons.live_tv_outlined,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  @override
  State<SimulateLiveButton> createState() => _SimulateLiveButtonState();
}

class _SimulateLiveButtonState extends State<SimulateLiveButton> {
  bool _isFocused = false;

  void _simulate() {
    final calendar = context.read<CalendarProvider>();
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      calendar.simulateLiveEventStarted(count: widget.eventCount);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final bgColor = _isFocused ? scheme.primary : scheme.surface;
    final iconColor = _isFocused ? scheme.onPrimary : scheme.onSurfaceVariant;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft) {
            if (widget.onKeyLeft != null) {
              widget.onKeyLeft!();
              return KeyEventResult.handled;
            }
          } else if (key == LogicalKeyboardKey.arrowRight) {
            if (widget.onKeyRight != null) {
              widget.onKeyRight!();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          } else if (key == LogicalKeyboardKey.arrowDown) {
            if (widget.onKeyDown != null) {
              widget.onKeyDown!();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          } else if (key == LogicalKeyboardKey.arrowUp) {
            if (widget.onKeyUp != null) {
              widget.onKeyUp!();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          } else if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            _simulate();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: _simulate,
        child: AnimatedScale(
          scale: _isFocused ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.icon,
              color: iconColor,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
