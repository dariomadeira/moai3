import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';

/// Panel mostrado en el área derecha cuando no hay canal activo / seleccionado.
/// Utiliza el panel común con su degradado y borde, conteniendo el estado vacío reutilizable [TvEmptyStateCard].
class EmptyViewerPanel extends StatelessWidget {
  final FocusNode focusNode;
  final bool hasChannels;
  final VoidCallback onReturnToPanel;
  final VoidCallback onKeyUp;

  const EmptyViewerPanel({
    super.key,
    required this.focusNode,
    required this.hasChannels,
    required this.onReturnToPanel,
    required this.onKeyUp,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final baseColor = scheme.surface.withValues(alpha: 0.8);
    final endColor = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.05),
      baseColor,
    );
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.48);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: [baseColor, baseColor, endColor],
          stops: const [0.0, 0.62, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.0,
        ),
      ),
      child: Center(
        child: TvEmptyStateCard(
          focusNode: focusNode,
          icon: MoaiIcons.tvEmptyViewer,
          message: hasChannels
              ? 'home_tv_viewer_empty'.tr()
              : 'home_tv_viewer_no_channels'.tr(),
          subtitle: hasChannels
              ? 'home_tv_viewer_empty_desc'.tr()
              : 'home_tv_viewer_no_channels_desc'.tr(),
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          onFocusUp: onKeyUp,
          onFocusLeft: onReturnToPanel,
          onFocusRight: onReturnToPanel,
          onTap: onReturnToPanel,
        ),
      ),
    );
  }
}
