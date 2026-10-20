import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/focus/focus_retry.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/tv_panel_header.dart';

/// Área de Inicio (Dashboard).
/// Panel único a ancho completo con estilo de acordeón TV.
class HomeDashboardArea extends StatefulWidget {
  final VoidCallback onExitLeft;

  const HomeDashboardArea({
    super.key,
    required this.onExitLeft,
  });

  @override
  State<HomeDashboardArea> createState() => HomeDashboardAreaState();
}

class HomeDashboardAreaState extends State<HomeDashboardArea> {
  final FocusNode _panelFocusNode = FocusNode(debugLabel: 'home_dashboard_panel');

  void requestEntryFocus() {
    if (!mounted) return;
    requestFocusWithRetry(_panelFocusNode, isMounted: () => mounted);
  }

  @override
  void dispose() {
    _panelFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return TvAccordionRowPreview(
      panelCount: 1,
      activeIndex: 0,
      colors: [scheme.surface.withValues(alpha: 0.8)],
      titles: ['home_panel_home_title'.tr()],
      icons: const [MoaiIcons.tvAccordionHome],
      onPanelTap: (_) {},
      buildExpandedContent: (index, title) {
        return Focus(
          focusNode: _panelFocusNode,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              widget.onExitLeft();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
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
                TvPanelHeader(
                  title: 'home_panel_home_title'.tr(),
                  subtitle: '',
                ),
                const Expanded(
                  child: SizedBox.expand(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
