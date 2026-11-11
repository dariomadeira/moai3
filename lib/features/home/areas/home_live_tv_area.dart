import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';

/// Visor de TV nuevo, rediseñado desde cero al lado del de siempre
/// ([HomeTvArea]). Por ahora, un solo panel a todo el ancho, como Películas
/// sin Buscar, con un aviso que toma el foco.
class HomeLiveTvArea extends StatefulWidget {
  final VoidCallback onExitLeft;

  const HomeLiveTvArea({super.key, required this.onExitLeft});

  @override
  State<HomeLiveTvArea> createState() => HomeLiveTvAreaState();
}

class HomeLiveTvAreaState extends HomeAreaState<HomeLiveTvArea> {
  late final _focus = FocusRequester(isMounted: () => mounted);
  final FocusNode _placeholderFocus = FocusNode(debugLabel: 'live_tv_empty');

  @override
  void requestEntryFocus() => _focus.node(_placeholderFocus);

  @override
  void dispose() {
    _placeholderFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TvAccordionRowPreview(
      panelCount: 1,
      activeIndex: 0,
      colors: [scheme.surface.withValues(alpha: 0.8)],
      titles: [LocaleKeys.live_tv_panel_title.tr()],
      icons: const [MoaiIcons.railLiveTv],
      onPanelTap: (_) {},
      buildExpandedContent: (index, title) => Center(
        child: TvEmptyStateCard(
          focusNode: _placeholderFocus,
          icon: MoaiIcons.railLiveTv,
          message: LocaleKeys.live_tv_placeholder.tr(),
          onFocusLeft: widget.onExitLeft,
        ),
      ),
    );
  }
}
