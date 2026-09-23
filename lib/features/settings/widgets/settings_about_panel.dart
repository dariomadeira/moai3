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
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:provider/provider.dart';

enum _AboutItemType {
  channelsLoaded,
  checkUpdates,
}

class SettingsAboutPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;

  const SettingsAboutPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
  });

  @override
  State<SettingsAboutPanel> createState() => SettingsAboutPanelState();
}

class SettingsAboutPanelState extends State<SettingsAboutPanel> {
  static const int _windowSize = 4;
  static const double _itemExtent = 74.0;

  final _listKey = GlobalKey<TvWindowedListState<_AboutItemType>>();
  int _selectedIndex = 0;
  bool _isChecking = false;
  String? _statusChip;

  void focusSelected() {
    _listKey.currentState?.ensureVisible(_selectedIndex);
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

    const items = _AboutItemType.values;

    if (_selectedIndex >= items.length) {
      _selectedIndex = items.length - 1;
    }

    final listAlign = items.length < _windowSize
        ? Alignment.topCenter
        : Alignment.bottomCenter;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          _listKey.currentState?.ensureVisible(_selectedIndex);
        }
      },
      child: Container(
        padding: const EdgeInsets.only(
          left: 4,
          right: 12,
          top: 8,
          bottom: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 4, bottom: 10),
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
                  const SizedBox(height: 2),
                  Text(
                    'settings_about_subtitle'.tr(),
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 220;
                      final image = Image.asset(
                        'assets/images/moaiAbout.png',
                        height: narrow ? 60 : 76,
                        width: narrow ? constraints.maxWidth : null,
                        fit: BoxFit.contain,
                      );
                      final meta = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/svgs/appLogo.svg',
                            height: narrow ? 20 : 26,
                            colorFilter: ColorFilter.mode(
                              scheme.onSurface,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'settings_about_version'.tr(
                              namedArgs: {'version': PlayerConfig.appVersion},
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MoaiText.body(
                              context,
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
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
                            const SizedBox(height: 8),
                            meta,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          image,
                          const SizedBox(width: 16),
                          Expanded(child: meta),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Align(
                alignment: listAlign,
                child: TvWindowedList<_AboutItemType>(
                  key: _listKey,
                  items: items,
                  windowSize: _windowSize,
                  itemExtent: _itemExtent,
                  showScrollDots: true,
                  initialGlobalIndex: _selectedIndex,
                  onFocusedGlobalIndex: (idx) {
                    _selectedIndex = idx;
                  },
                  itemBuilder: (
                    context,
                    item,
                    focusNode,
                    local,
                    global,
                    onKeyUp,
                    onKeyDown,
                  ) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _buildItem(
                        context: context,
                        item: item,
                        valueText: valueText,
                        scheme: scheme,
                        focusNode: focusNode,
                        onKeyUp: onKeyUp,
                        onKeyDown: onKeyDown,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required _AboutItemType item,
    required String valueText,
    required ColorScheme scheme,
    required FocusNode focusNode,
    required VoidCallback onKeyUp,
    required VoidCallback onKeyDown,
  }) {
    switch (item) {
      case _AboutItemType.channelsLoaded:
        return TvTile(
          focusNode: focusNode,
          label: 'settings_about_channels_loaded'.tr(),
          icon: Symbols.tv_guide,
          onKeyLeft: widget.onKeyLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
          trailingBuilder: (context, isFocused) {
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
                  valueText,
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
      case _AboutItemType.checkUpdates:
        return TvTile(
          focusNode: focusNode,
          icon: Symbols.browser_updated,
          label: 'settings_about_check_updates'.tr(),
          description: 'settings_about_check_updates_desc'.tr(),
          onKeyLeft: widget.onKeyLeft,
          onKeyUp: onKeyUp,
          onKeyDown: onKeyDown,
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
        );
    }
  }
}
