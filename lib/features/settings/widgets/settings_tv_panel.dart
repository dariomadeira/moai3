import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/features/settings/widgets/settings_widgets.dart';
import 'package:moai3/features/sources/screens/sources_screen.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:provider/provider.dart';

import 'package:moai3/widgets/dialogs/tv_pin_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';

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
  final FocusNode _adultFocusNode = FocusNode(debugLabel: 'tv_adult');
  final FocusNode _changePinFocusNode = FocusNode(debugLabel: 'tv_change_pin');
  final FocusNode _sourcesFocusNode = FocusNode(debugLabel: 'tv_sources');

  @override
  void dispose() {
    _adultFocusNode.dispose();
    _changePinFocusNode.dispose();
    _sourcesFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tvSettings = context.watch<TvSettingsProvider>();
    final hasPin = tvSettings.hasParentalPin;

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
              onKeyDown: () => _adultFocusNode.requestFocus(),
            ),
            const SizedBox(height: 12),
            TvSettingsSwitchRow(
              focusNode: _adultFocusNode,
              icon: tvSettings.isAdultUnlocked ? Symbols.lock_open : Symbols.lock,
              label: 'settings_tv_adult_content'.tr(),
              description: 'settings_tv_adult_content_desc'.tr(),
              value: tvSettings.isAdultUnlocked,
              onChanged: (enable) async {
                if (enable) {
                  await TvPinDialog.unlockAdultSession(context, tvSettings);
                } else {
                  tvSettings.lockAdult();
                  if (context.mounted) {
                    MoaiSnackBar.show(
                      context,
                      message: 'parental_adult_locked'.tr(),
                      icon: Symbols.lock,
                    );
                  }
                }
              },
              onKeyLeft: widget.onKeyLeft,
              onKeyRight: widget.onKeyRight,
              onKeyUp: () => widget.focusNode.requestFocus(),
              onKeyDown: () => hasPin
                  ? _changePinFocusNode.requestFocus()
                  : _sourcesFocusNode.requestFocus(),
            ),
            if (hasPin) ...[
              const SizedBox(height: 12),
              TvSettingsActionRow(
                focusNode: _changePinFocusNode,
                icon: Icons.pin_outlined,
                label: 'settings_tv_change_pin'.tr(),
                description: 'settings_tv_change_pin_desc'.tr(),
                onPressed: () async {
                  await TvPinDialog.changePin(context, tvSettings);
                },
                onKeyLeft: widget.onKeyLeft,
                onKeyRight: widget.onKeyRight,
                onKeyUp: () => _adultFocusNode.requestFocus(),
                onKeyDown: () => _sourcesFocusNode.requestFocus(),
              ),
            ],
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
              onKeyUp: () => hasPin
                  ? _changePinFocusNode.requestFocus()
                  : _adultFocusNode.requestFocus(),
            ),
          ],
        ),
      ),
    );
  }
}

