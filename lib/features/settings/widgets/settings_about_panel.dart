import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/config/player_config.dart';
import 'package:moai3/features/settings/widgets/tv_tile.dart';
import 'package:moai3/services/update_service.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/update_dialog.dart';
import 'package:provider/provider.dart';

class SettingsAboutPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;

  const SettingsAboutPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
  });

  @override
  State<SettingsAboutPanel> createState() => _SettingsAboutPanelState();
}

class _SettingsAboutPanelState extends State<SettingsAboutPanel> {
  final FocusNode _updateFocusNode = FocusNode(debugLabel: 'about_update_tile');
  bool _isChecking = false;
  String? _statusChip;

  @override
  void dispose() {
    _updateFocusNode.dispose();
    super.dispose();
  }

  Future<void> _checkUpdate() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _statusChip = null;
    });

    final updateInfo = await UpdateService.checkForUpdate();

    if (!mounted) return;

    setState(() {
      _isChecking = false;
    });

    if (updateInfo != null) {
      UpdateDialog.show(context, updateInfo);
    } else {
      setState(() {
        _statusChip = 'settings_about_up_to_date'.tr();
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _statusChip = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final channelProv = context.watch<ChannelProvider>();
    final channelCount = channelProv.allChannels.length;
    final isLoading = channelProv.isLoadingChannels;

    final String valueText;
    if (channelCount > 0) {
      valueText =
          'home_channels_count'.tr(namedArgs: {'count': '$channelCount'});
    } else if (isLoading) {
      valueText = 'settings_about_loading'.tr();
    } else {
      valueText = 'settings_about_empty'.tr();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'settings_about_title'.tr(),
              style: MoaiText.display(
                context,
                color: scheme.onSurface,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'settings_about_subtitle'.tr(),
              style: MoaiText.body(
                context,
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 220;
                final image = Image.asset(
                  'assets/images/moaiAbout.png',
                  height: narrow ? 72 : 110,
                  width: narrow ? constraints.maxWidth : null,
                  fit: BoxFit.contain,
                );
                final meta = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/svgs/appLogo.svg',
                      height: narrow ? 24 : 32,
                      colorFilter: ColorFilter.mode(
                        scheme.onSurface,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'settings_about_version'.tr(
                        namedArgs: {'version': PlayerConfig.appVersion},
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MoaiText.body(
                        context,
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      image,
                      const SizedBox(height: 12),
                      meta,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    image,
                    const SizedBox(width: 20),
                    Expanded(child: meta),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _AboutInfoRow(
              focusNode: widget.focusNode,
              icon: Symbols.tv_guide,
              label: 'settings_about_channels_loaded'.tr(),
              value: valueText,
              onKeyLeft: widget.onKeyLeft,
              onKeyDown: () => _updateFocusNode.requestFocus(),
            ),
            const SizedBox(height: 10),
            TvTile(
              focusNode: _updateFocusNode,
              icon: Symbols.system_update_rounded,
              label: 'settings_about_check_updates'.tr(),
              description: 'settings_about_check_updates_desc'.tr(),
              onKeyLeft: widget.onKeyLeft,
              onKeyUp: () => widget.focusNode.requestFocus(),
              onPressed: _checkUpdate,
              trailingBuilder: (context, isFocused) {
                if (_isChecking) {
                  return SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isFocused ? scheme.onPrimary : scheme.primary,
                      ),
                    ),
                  );
                }
                if (_statusChip != null) {
                  final chipBg = isFocused
                      ? scheme.onPrimary.withValues(alpha: 0.18)
                      : scheme.primaryContainer;
                  final chipFg =
                      isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;

                  return Material(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Text(
                        _statusChip!,
                        style: MoaiText.body(
                          context,
                          color: chipFg,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }
                return Icon(
                  Symbols.chevron_right,
                  color: isFocused ? scheme.onPrimary : scheme.onSurfaceVariant,
                  size: 20,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutInfoRow extends StatelessWidget {
  final FocusNode focusNode;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onKeyLeft;
  final VoidCallback? onKeyDown;

  const _AboutInfoRow({
    required this.focusNode,
    required this.icon,
    required this.label,
    required this.value,
    required this.onKeyLeft,
    this.onKeyDown,
  });

  @override
  Widget build(BuildContext context) {
    return TvTile(
      focusNode: focusNode,
      label: label,
      icon: icon,
      onKeyLeft: onKeyLeft,
      onKeyDown: onKeyDown,
      trailingBuilder: (context, isFocused) {
        final scheme = context.scheme;
        final chipBg = isFocused
            ? scheme.onPrimary.withValues(alpha: 0.18)
            : scheme.secondaryContainer;
        final chipFg =
            isFocused ? scheme.onPrimary : scheme.onSecondaryContainer;

        return Material(
          color: chipBg,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            child: Text(
              value,
              style: MoaiText.body(
                context,
                color: chipFg,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      },
    );
  }
}
