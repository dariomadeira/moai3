import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/features/sources/screens/sources_screen.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:provider/provider.dart';

class SettingsTvPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;

  const SettingsTvPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
  });

  @override
  State<SettingsTvPanel> createState() => _SettingsTvPanelState();
}

class _SettingsTvPanelState extends State<SettingsTvPanel> {
  final FocusNode _sourcesFocusNode = FocusNode(debugLabel: 'tv_sources');

  @override
  void dispose() {
    _sourcesFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tvSettings = context.watch<TvSettingsProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'settings_tv_title'.tr(),
              style: MoaiText.display(
                context,
                color: scheme.onSurface,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'settings_tv_subtitle'.tr(),
              style: MoaiText.body(
                context,
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 20),
            TvSettingsSwitchRow(
              focusNode: widget.focusNode,
              icon: Icons.terminal_outlined,
              label: 'settings_tv_log'.tr(),
              description: 'settings_tv_log_desc'.tr(),
              value: tvSettings.showTvLog,
              onChanged: (v) => tvSettings.setShowTvLog(v),
              onKeyLeft: widget.onKeyLeft,
              onKeyRight: widget.onKeyRight,
              onKeyDown: () => _sourcesFocusNode.requestFocus(),
            ),
            const SizedBox(height: 12),
            TvSettingsActionRow(
              focusNode: _sourcesFocusNode,
              icon: Symbols.extension,
              label: 'settings_general_sources'.tr(),
              description: 'settings_general_sources_desc'.tr(),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SourcesScreen(),
                  ),
                );
              },
              onKeyLeft: widget.onKeyLeft,
              onKeyRight: widget.onKeyRight,
              onKeyUp: () => widget.focusNode.requestFocus(),
            ),
          ],
        ),
      ),
    );
  }
}

