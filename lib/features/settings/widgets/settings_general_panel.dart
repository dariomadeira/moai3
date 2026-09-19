import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/bootstrap/screens/overlap_config_screen.dart';
import 'package:moai3/features/settings/widgets/settings_accent_color_row.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/state/theme_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:provider/provider.dart';

class SettingsGeneralPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;

  const SettingsGeneralPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
  });

  @override
  State<SettingsGeneralPanel> createState() => _SettingsGeneralPanelState();
}

class _SettingsGeneralPanelState extends State<SettingsGeneralPanel> {
  final FocusNode _darkModeFocusNode = FocusNode(debugLabel: 'general_dark_mode');
  final FocusNode _accentFocusNode = FocusNode(debugLabel: 'general_accent');
  final FocusNode _autoAccentFocusNode =
      FocusNode(debugLabel: 'general_auto_accent');

  @override
  void dispose() {
    _darkModeFocusNode.dispose();
    _accentFocusNode.dispose();
    _autoAccentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final theme = context.watch<ThemeProvider>();
    final isAutoAccent = theme.autoAccent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'settings_general_title'.tr(),
              style: MoaiText.display(
                context,
                color: scheme.onSurface,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'settings_general_subtitle'.tr(),
              style: MoaiText.body(
                context,
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 20),
            TvSettingsActionRow(
              focusNode: widget.focusNode,
              icon: Icons.aspect_ratio_outlined,
              label: 'settings_general_overscan'.tr(),
              description: 'settings_general_overscan_desc'.tr(),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        const OverlapConfigScreen(isFirstRun: false),
                  ),
                );
              },
              onKeyLeft: widget.onKeyLeft,
              onKeyRight: widget.onKeyRight,
              onKeyDown: () => _darkModeFocusNode.requestFocus(),
            ),
            const SizedBox(height: 12),
            TvSettingsSwitchRow(
              focusNode: _darkModeFocusNode,
              icon: Icons.dark_mode_outlined,
              label: 'settings_general_dark_mode'.tr(),
              description: 'settings_general_dark_mode_desc'.tr(),
              value: theme.themeMode == ThemeMode.dark,
              onChanged: (isDark) {
                theme.setDarkMode(isDark);
              },
              onKeyLeft: widget.onKeyLeft,
              onKeyRight: widget.onKeyRight,
              onKeyUp: () => widget.focusNode.requestFocus(),
              onKeyDown: () => isAutoAccent
                  ? _autoAccentFocusNode.requestFocus()
                  : _accentFocusNode.requestFocus(),
            ),
            if (!isAutoAccent) ...[
              const SizedBox(height: 12),
              SettingsAccentColorRow(
                focusNode: _accentFocusNode,
                icon: Icons.palette_outlined,
                selectedIndex: theme.accentColorIndex,
                onChanged: (index) => theme.setAccentColorIndex(index),
                onKeyUp: () => _darkModeFocusNode.requestFocus(),
                onKeyDown: () => _autoAccentFocusNode.requestFocus(),
              ),
            ],
            const SizedBox(height: 12),
            TvSettingsSwitchRow(
              focusNode: _autoAccentFocusNode,
              icon: Icons.auto_awesome_outlined,
              label: 'settings_general_auto_accent'.tr(),
              description: 'settings_general_auto_accent_desc'.tr(),
              value: isAutoAccent,
              onChanged: (auto) {
                theme.setAutoAccent(auto);
              },
              onKeyLeft: widget.onKeyLeft,
              onKeyRight: widget.onKeyRight,
              onKeyUp: () => isAutoAccent
                  ? _darkModeFocusNode.requestFocus()
                  : _accentFocusNode.requestFocus(),
            ),
          ],
        ),
      ),
    );
  }
}
