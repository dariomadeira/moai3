import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/features/movies/widgets/movie_detail_parts.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/tv_common/moai_ambient_background.dart';
import 'package:provider/provider.dart';

/// El armado común de las fichas de película y de serie: el fondo de la
/// app, el botón de atrás a la izquierda y un solo panel de acordeón con la
/// foto difuminada arriba a la derecha y [content] encima.
class MovieDetailShell extends StatelessWidget {
  const MovieDetailShell({
    super.key,
    required this.backFocusNode,
    required this.onBackForward,
    required this.tabTitle,
    required this.ambientUrl,
    required this.content,
    this.svgIcon,
    this.tabBuilder,
  });

  final FocusNode backFocusNode;

  /// → o ↓ desde atrás: al contenido.
  final VoidCallback onBackForward;

  final String tabTitle;

  /// Ícono SVG de la pestaña (si no, el póster).
  final String? svgIcon;

  /// Pestaña propia (si no, la de siempre del acordeón).
  final Widget Function(int index, bool isExpanded)? tabBuilder;

  /// La foto difuminada de la esquina; sin ella, nada.
  final String? ambientUrl;

  final Widget content;

  @override
  Widget build(BuildContext context) {
    final overlapX = context.select(
      (TvSettingsProvider s) => s.overlapPaddingX,
    );
    final overlapY = context.select(
      (TvSettingsProvider s) => s.overlapPaddingY,
    );
    final ambientUrl = this.ambientUrl;
    final svgIcon = this.svgIcon;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: MoaiAmbientBackground()),
          ),
          SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: overlapX,
                vertical: overlapY,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 54,
                    child: Column(
                      children: [
                        const SizedBox(height: 9),
                        TvBackPill(
                          focusNode: backFocusNode,
                          onKeyRight: onBackForward,
                          onKeyDown: onBackForward,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                      child: TvAccordionRowPreview(
                        panelCount: 1,
                        activeIndex: 0,
                        titles: [tabTitle],
                        icons: const [MoaiIcons.vodPoster],
                        svgIcons: svgIcon == null ? null : [svgIcon],
                        onPanelTap: (_) {},
                        tabBuilder: tabBuilder,
                        buildExpandedContent: (index, title) => ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(15),
                            bottomRight: Radius.circular(15),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Si hay una sola foto, se duplica difuminada
                              // en la esquina.
                              if (ambientUrl != null && ambientUrl.isNotEmpty)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  width: movieDetailAmbientWidth,
                                  height: movieDetailAmbientHeight,
                                  child: IgnorePointer(
                                    child: MovieDetailAmbient(
                                      imageUrl: ambientUrl,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                child: content,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
