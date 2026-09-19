import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/widgets/tv_input/tv_keyboard_type.dart';

enum TvKeyAction {
  character,
  space,
  backspace,
  clear,
  shift,
  switchDigits,
  switchLetters,
  cancel,
  done,
}

class TvKeyDef {
  final String? label;
  final String? character;
  final TvKeyAction action;
  final double flex;

  const TvKeyDef({
    this.label,
    this.character,
    this.action = TvKeyAction.character,
    this.flex = 1,
  }) : assert(
          action != TvKeyAction.character || character != null,
          'character keys need a character',
        );
}

abstract final class TvKeyboardLayouts {
  static List<TvKeyDef> _chars(String raw) => [
        for (final ch in raw.split(''))
          TvKeyDef(label: ch, character: ch),
      ];

  static List<TvKeyDef> _charsMapped(String raw, String Function(String) map) =>
      [
        for (final ch in raw.split(''))
          TvKeyDef(label: map(ch), character: map(ch)),
      ];

  static List<List<TvKeyDef>> forType(
    TvKeyboardType type, {
    required bool digitsMode,
    required bool shift,
  }) {
    switch (type) {
      case TvKeyboardType.number:
      case TvKeyboardType.port:
        return _numeric(includeDot: false);
      case TvKeyboardType.ip:
        return _numeric(includeDot: true);
      case TvKeyboardType.text:
      case TvKeyboardType.search:
        return digitsMode ? _digitsPad() : _qwerty(shift: shift);
    }
  }

  static List<List<TvKeyDef>> _qwerty({required bool shift}) {
    String c(String lower) => shift ? lower.toUpperCase() : lower;

    return [
      _chars('1234567890'),
      _charsMapped('qwertyuiop', c),
      _charsMapped('asdfghjkl', c),
      [
        const TvKeyDef(label: '⇧', action: TvKeyAction.shift, flex: 1.2),
        ..._charsMapped('zxcvbnm', c),
        const TvKeyDef(label: '⌫', action: TvKeyAction.backspace, flex: 1.2),
      ],
      [
        const TvKeyDef(
          label: '123',
          action: TvKeyAction.switchDigits,
          flex: 1.4,
        ),
        TvKeyDef(
          label: 'keyboard_space'.tr(),
          action: TvKeyAction.space,
          flex: 4,
        ),
        TvKeyDef(
          label: 'keyboard_clear'.tr(),
          action: TvKeyAction.clear,
          flex: 1.6,
        ),
      ],
    ];
  }

  static List<List<TvKeyDef>> _digitsPad() {
    return [
      _chars('1234567890'),
      _chars('@#\$%&*()-_'),
      [
        ..._chars('.,;:!?"\'/'),
        const TvKeyDef(label: '⌫', action: TvKeyAction.backspace, flex: 1.4),
      ],
      [
        const TvKeyDef(
          label: 'ABC',
          action: TvKeyAction.switchLetters,
          flex: 1.4,
        ),
        TvKeyDef(
          label: 'keyboard_space'.tr(),
          action: TvKeyAction.space,
          flex: 4,
        ),
        TvKeyDef(
          label: 'keyboard_clear'.tr(),
          action: TvKeyAction.clear,
          flex: 1.6,
        ),
      ],
    ];
  }

  static List<List<TvKeyDef>> _numeric({required bool includeDot}) {
    return [
      _chars('123'),
      _chars('456'),
      _chars('789'),
      [
        if (includeDot)
          const TvKeyDef(label: '.', character: '.')
        else
          TvKeyDef(
            label: 'keyboard_clear'.tr(),
            action: TvKeyAction.clear,
            flex: 1.2,
          ),
        const TvKeyDef(label: '0', character: '0'),
        const TvKeyDef(label: '⌫', action: TvKeyAction.backspace),
        if (includeDot)
          TvKeyDef(
            label: 'keyboard_clear'.tr(),
            action: TvKeyAction.clear,
            flex: 1.4,
          ),
      ],
    ];
  }
}

