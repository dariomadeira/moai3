import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/playback_stats_controller.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';

/// Contenedor base del panel derecho del visor TV que se extiende hasta arriba.
///
/// Aloja el header (TvWatchPartyHeaderBar / título del canal), las pills de metadatos
/// y el área del visor/reproductor.
class TvViewerPanel extends StatelessWidget {
  final Widget? header;
  final Channel? channel;
  final Widget? child;

  const TvViewerPanel({
    super.key,
    this.header,
    this.channel,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final baseColor = scheme.surface.withValues(alpha: 0.8);
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.48);

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 16, right: 16),
              child: header!,
            ),
          if (channel != null) _buildChannelPills(context, channel!, scheme),
          if (child != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: child!,
            ),
        ],
      ),
    );
  }

  Widget _buildChannelPills(
    BuildContext context,
    Channel ch,
    ColorScheme scheme,
  ) {
    final fallbackIndex =
        context.select((PlaybackStatsController s) => s.fallbackIndex);
    final isPuppeteer =
        context.select((ChannelProvider s) => s.isPuppeteerEngine);

    var displayServerNumber = fallbackIndex + 1;
    if (ch.fallbackUrls.isNotEmpty &&
        fallbackIndex >= 0 &&
        fallbackIndex < ch.fallbackUrls.length) {
      final uri = Uri.tryParse(ch.fallbackUrls[fallbackIndex]);
      final playerParam = uri?.queryParameters['player'];
      if (playerParam != null) {
        final parsed = int.tryParse(playerParam);
        if (parsed != null) displayServerNumber = parsed;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 14, right: 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (ch.country.trim().isNotEmpty)
            TvMetaPill(
              color: scheme.tertiaryContainer,
              foreground: scheme.onTertiaryContainer,
              icon: MoaiIcons.tvViewerPillCountry,
              label: ch.country,
            ),
          if (ch.category.trim().isNotEmpty)
            TvMetaPill(
              color: scheme.tertiaryContainer,
              foreground: scheme.onTertiaryContainer,
              icon: MoaiIcons.tvViewerPillCategory,
              label: ch.category,
            ),
          if (ch.pluginTag != null && ch.pluginTag!.trim().isNotEmpty)
            TvMetaPill(
              color: scheme.tertiaryContainer,
              foreground: scheme.onTertiaryContainer,
              icon: MoaiIcons.tvViewerPillPlugin,
              label: ch.pluginTag!.trim(),
            ),
          if (ch.fallbackUrls.length > 1 && !isPuppeteer)
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
    );
  }
}
