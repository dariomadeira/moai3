import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/settings/screens/accent_color_screen.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/theme/moai_accent_colors.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';

class SettingsAccentColorRow extends StatelessWidget {
  final FocusNode focusNode;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;
  final IconData? icon;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const SettingsAccentColorRow({
    super.key,
    required this.focusNode,
    required this.selectedIndex,
    this.onChanged,
    this.icon,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  void _openScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AccentColorScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorName = selectedIndex >= 0 &&
            selectedIndex < MoaiAccentColors.labelKeys.length
        ? MoaiAccentColors.labelKeys[selectedIndex].tr()
        : '';

    final baseLabel = LocaleKeys.settings_general_accent.tr();
    final label = colorName.isNotEmpty ? '$baseLabel - $colorName' : baseLabel;

    return TvTile(
      focusNode: focusNode,
      label: label,
      description: LocaleKeys.settings_general_accent_desc.tr(),
      icon: icon ?? MoaiIcons.paletteOutlined,
      onPressed: () => _openScreen(context),
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
      trailingBuilder: (context, isFocused) {
        final scheme = context.scheme;
        return Icon(
          MoaiIcons.chevronRight,
          size: 26,
          color: isFocused ? scheme.onPrimary : scheme.onSurfaceVariant,
        );
      },
    );
  }
}
