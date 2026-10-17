import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/widgets/tv_panel_header_metrics.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/playback_stats_controller.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';

/// Título + meta del canal alineados con [PanelListHeader].
class ChannelViewerHeader extends StatelessWidget {
  final Channel channel;

  const ChannelViewerHeader({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final fallbackIndex =
        context.select((PlaybackStatsController s) => s.fallbackIndex);
    final isPuppeteer =
        context.select((ChannelProvider s) => s.isPuppeteerEngine);

    var displayServerNumber = fallbackIndex + 1;
    if (channel.fallbackUrls.isNotEmpty &&
        fallbackIndex >= 0 &&
        fallbackIndex < channel.fallbackUrls.length) {
      final uri = Uri.tryParse(channel.fallbackUrls[fallbackIndex]);
      final playerParam = uri?.queryParameters['player'];
      if (playerParam != null) {
        final parsed = int.tryParse(playerParam);
        if (parsed != null) displayServerNumber = parsed;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: TvPanelHeaderMetrics.viewerTopInset),
        Text(
          channel.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MoaiText.display(
            context,
            color: scheme.onSurface,
            fontSize: TvPanelHeaderMetrics.titleFontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: TvPanelHeaderMetrics.titleSubtitleGap),
        Wrap(
          spacing: 4,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TvMetaPill(
              color: scheme.tertiaryContainer,
              foreground: scheme.onTertiaryContainer,
              icon: MoaiIcons.tvViewerPillCountry,
              label: channel.country,
            ),
            TvMetaPill(
              color: scheme.tertiaryContainer,
              foreground: scheme.onTertiaryContainer,
              icon: MoaiIcons.tvViewerPillCategory,
              label: channel.category,
            ),
            if (channel.pluginTag != null && channel.pluginTag!.trim().isNotEmpty)
              TvMetaPill(
                color: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
                icon: MoaiIcons.tvViewerPillPlugin,
                label: channel.pluginTag!.trim(),
              ),
            if (channel.fallbackUrls.length > 1 && !isPuppeteer)
              TvMetaPill(
                color: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
                icon: MoaiIcons.dnsOutlined,
                label: 'player_server_n'.tr(
                  namedArgs: {'n': '$displayServerNumber'},
                ),
              ),
          ],
        ),
        const SizedBox(height: TvPanelHeaderMetrics.bottomInset),
      ],
    );
  }
}

