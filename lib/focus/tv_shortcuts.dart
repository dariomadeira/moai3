import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:moai3/focus/tv_intents.dart';

abstract final class TvShortcuts {
  static Map<ShortcutActivator, Intent> get dpad => {
        // Sin repeats: hold de ←/→ no thrash paneles (Actions).
        const SingleActivator(
          LogicalKeyboardKey.arrowLeft,
          includeRepeats: false,
        ): const DpadLeftIntent(),
        const SingleActivator(
          LogicalKeyboardKey.arrowRight,
          includeRepeats: false,
        ): const DpadRightIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): const DpadUpIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            const DpadDownIntent(),
        const SingleActivator(LogicalKeyboardKey.goBack): const DpadBackIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const DpadBackIntent(),
      };
}

