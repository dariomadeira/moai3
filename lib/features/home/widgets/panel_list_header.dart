import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/tv_panel_header_metrics.dart';
import 'package:moai3/theme/moai_text.dart';

/// Encabezado de subtítulo de un panel del acordeón TV.
class PanelListHeader extends StatelessWidget {
  final String subtitle;
  final bool showFilterText;

  const PanelListHeader({
    super.key,
    required this.subtitle,
    this.showFilterText = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: TvPanelHeaderMetrics.topInset + 4),
        Text(
          subtitle,
          style: MoaiText.display(
            context,
            color: scheme.onSurface,
            fontSize: TvPanelHeaderMetrics.subtitleFontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (showFilterText) ...[
          const SizedBox(height: TvPanelHeaderMetrics.titleSubtitleGap),
          Text(
            'search_hint_with_filter'.tr(),
            style: MoaiText.body(
              context,
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: TvPanelHeaderMetrics.titleSubtitleGap),
        ] else ...[
          const SizedBox(height: TvPanelHeaderMetrics.titleSubtitleGap),
        ],
      ],
    );
  }
}
