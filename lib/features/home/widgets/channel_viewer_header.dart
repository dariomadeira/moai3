import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/widgets/tv_panel_header_metrics.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/playback_stats_controller.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/theme/moai_text.dart';

/// Título + meta del canal alineados con [PanelListHeader].
class ChannelViewerHeader extends StatelessWidget {
  final Channel channel;

  const ChannelViewerHeader({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final metaStyle = MoaiText.body(
      context,
      color: scheme.onSurface.withValues(alpha: 0.85),
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );

    final fallbackIndex =
        context.select((PlaybackStatsController s) => s.fallbackIndex);
    final isPuppeteer =
        context.select((ChannelProvider s) => s.isPuppeteerEngine);

    var displayServerNumber = fallbackIndex + 1;
    if (channel.fallbackUrls.isNotEmpty &&
        fallbackIndex >= 0 &&
        fallbackIndex < channel.fallbackUrls.length) {
      try {
        final uri = Uri.parse(channel.fallbackUrls[fallbackIndex]);
        final playerParam = uri.queryParameters['player'];
        if (playerParam != null) {
          displayServerNumber = int.parse(playerParam);
        }
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: TvPanelHeaderMetrics.topInset),
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
            _MetaPill(
              color: scheme.tertiaryContainer,
              foreground: scheme.onTertiaryContainer,
              icon: Icons.public_outlined,
              label: channel.country,
              textStyle: metaStyle.copyWith(color: scheme.onTertiaryContainer),
            ),
            _MetaPill(
              color: scheme.tertiaryContainer,
              foreground: scheme.onTertiaryContainer,
              icon: Icons.category_outlined,
              label: channel.category,
              textStyle: metaStyle.copyWith(color: scheme.onTertiaryContainer),
            ),
            if (channel.pluginTag != null && channel.pluginTag!.trim().isNotEmpty)
              _MetaPill(
                color: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
                icon: Icons.extension_outlined,
                label: channel.pluginTag!.trim(),
                textStyle:
                    metaStyle.copyWith(color: scheme.onTertiaryContainer),
              ),
            if (channel.fallbackUrls.length > 1 && !isPuppeteer)
              _MetaPill(
                color: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
                icon: Icons.dns_outlined,
                label: 'player_server_n'.tr(
                  namedArgs: {'n': '$displayServerNumber'},
                ),
                textStyle:
                    metaStyle.copyWith(color: scheme.onTertiaryContainer),
              ),
          ],
        ),
        const SizedBox(height: TvPanelHeaderMetrics.bottomInset),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;
  final TextStyle textStyle;

  const _MetaPill({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 4),
          Text(label, style: textStyle),
        ],
      ),
    );
  }
}

