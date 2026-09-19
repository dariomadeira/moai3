import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/theme/moai_text.dart';

class ServerSkipButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const ServerSkipButton({
    super.key,
    required this.focusNode,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  @override
  State<ServerSkipButton> createState() => _ServerSkipButtonState();
}

class _ServerSkipButtonState extends State<ServerSkipButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
      },
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft) {
          widget.onKeyLeft?.call();
          return widget.onKeyLeft != null
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          widget.onKeyRight?.call();
          return widget.onKeyRight != null
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          widget.onKeyDown?.call();
          return widget.onKeyDown != null
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        }
        if (key == LogicalKeyboardKey.arrowUp) {
          widget.onKeyUp?.call();
          return widget.onKeyUp != null
              ? KeyEventResult.handled
              : KeyEventResult.ignored;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.space) {
          context.read<ChannelProvider>().skipServer();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => context.read<ChannelProvider>().skipServer(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isFocused ? scheme.primary : scheme.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Symbols.host,
                color: _isFocused ? scheme.onPrimary : scheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'player_change_server'.tr(),
                style: MoaiText.body(
                  context,
                  color:
                      _isFocused ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

