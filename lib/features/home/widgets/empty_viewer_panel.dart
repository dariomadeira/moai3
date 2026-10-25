import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Panel mostrado en el área derecha cuando no hay canal activo / seleccionado.
/// Mismo cristal que los paneles del acordeón, con el estado vacío
/// reutilizable [TvEmptyStateCard] adentro.
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
    return MoaiGlass(
      borderRadius: 16,
      solid: true,
      elevated: false,
      child: Center(
        child: TvEmptyStateCard(
          focusNode: focusNode,
          icon: MoaiIcons.tvEmptyViewer,
          message: hasChannels
              ? LocaleKeys.home_tv_viewer_empty.tr()
              : LocaleKeys.home_tv_viewer_no_channels.tr(),
          subtitle: hasChannels
              ? LocaleKeys.home_tv_viewer_empty_desc.tr()
              : LocaleKeys.home_tv_viewer_no_channels_desc.tr(),
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
