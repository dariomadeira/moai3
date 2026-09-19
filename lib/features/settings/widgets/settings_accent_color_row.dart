import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/settings/widgets/tv_tile.dart';
import 'package:moai3/theme/moai_accent_colors.dart';
import 'package:moai3/theme/moai_text.dart';

class SettingsAccentColorRow extends StatelessWidget {
  final FocusNode focusNode;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final IconData? icon;
  final VoidCallback? onKeyUp;

  const SettingsAccentColorRow({
    super.key,
    required this.focusNode,
    required this.selectedIndex,
    required this.onChanged,
    this.icon,
    this.onKeyUp,
  });

  void _select(int index) {
    final next = MoaiAccentColors.clampIndex(index);
    if (next != selectedIndex) {
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvTile(
      focusNode: focusNode,
      label: 'settings_general_accent'.tr(),
      description: 'settings_general_accent_desc'.tr(),
      icon: icon,
      onKeyUp: onKeyUp,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;

        if (key == LogicalKeyboardKey.arrowUp && onKeyUp != null) {
          onKeyUp!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          if (selectedIndex > 0) {
            _select(selectedIndex - 1);
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          if (selectedIndex < MoaiAccentColors.seeds.length - 1) {
            _select(selectedIndex + 1);
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      trailingBuilder: (context, isFocused) {
        final scheme = context.scheme;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            MoaiAccentColors.seeds.length,
            (i) {
              final isSelected = i == selectedIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: isSelected ? 22 : 16,
                  height: isSelected ? 22 : 16,
                  decoration: BoxDecoration(
                    color: MoaiAccentColors.seeds[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? (isFocused ? scheme.onPrimary : scheme.onSurface)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

