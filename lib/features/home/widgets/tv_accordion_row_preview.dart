import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/collapsed_panel_tab_preview.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Acordeón horizontal TV: un panel expandido + tabs colapsados.
/// Conserva el estado y foco de los paneles montados al alternar entre pestañas.
class TvAccordionRowPreview extends StatefulWidget {
  final int panelCount;
  final int activeIndex;
  final List<Color> colors;
  final List<String> titles;
  final List<IconData> icons;
  final int? alphabetModePanelIndex;
  final Widget Function(int panelIndex)? alphabetPanelBuilder;
  final Widget Function(int index, bool isExpanded)? tabBuilder;
  final ValueChanged<int> onPanelTap;
  final Widget Function(int index, String title) buildExpandedContent;

  /// El contenido se arma siempre con su ancho final ([contentWidth]): mientras
  /// el panel anima su ancho, el recorte lo descubre como una cortina en vez
  /// de re-layoutearlo cuadro a cuadro.
  final bool fixedContentWidth;

  static const double collapsedWidth = 44.0;
  static const double gap = 6.0;

  const TvAccordionRowPreview({
    super.key,
    required this.panelCount,
    required this.activeIndex,
    required this.colors,
    required this.titles,
    required this.icons,
    this.alphabetModePanelIndex,
    this.alphabetPanelBuilder,
    this.tabBuilder,
    required this.onPanelTap,
    required this.buildExpandedContent,
    this.fixedContentWidth = false,
  });

  /// Ancho del contenido del panel abierto: el panel menos su pestaña y, sin
  /// cristal, el borde de 1 px de cada lado.
  static double contentWidth({
    required double totalWidth,
    required int panelCount,
    required bool glass,
  }) {
    final expanded = totalWidth - (collapsedWidth + gap) * (panelCount - 1);
    final width = expanded - (collapsedWidth - 2.0) - (glass ? 0.0 : 2.0);
    return width < 0 ? 0 : width;
  }

  @override
  State<TvAccordionRowPreview> createState() => _TvAccordionRowPreviewState();
}

class _TvAccordionRowPreviewState extends State<TvAccordionRowPreview> {
  final Set<int> _mountedPanels = {};

  @override
  void initState() {
    super.initState();
    _mountedPanels.add(widget.activeIndex);
  }

  @override
  void didUpdateWidget(covariant TvAccordionRowPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _mountedPanels.add(widget.activeIndex);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const collapsedWidth = TvAccordionRowPreview.collapsedWidth;
        const gap = TvAccordionRowPreview.gap;
        final totalWidth = constraints.maxWidth;
        final totalGaps = gap * (widget.panelCount - 1);
        final expandedWidth =
            totalWidth - (collapsedWidth * (widget.panelCount - 1)) - totalGaps;

        final scheme = Theme.of(context).colorScheme;
        final borderExpanded = scheme.outlineVariant.withValues(alpha: 0.48);
        final borderCollapsed = scheme.outlineVariant.withValues(alpha: 0.38);
        final glass = MoaiGlassScope.enabledOf(context);
        final contentWidth = TvAccordionRowPreview.contentWidth(
          totalWidth: totalWidth,
          panelCount: widget.panelCount,
          glass: glass,
        );

        return RepaintBoundary(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(widget.panelCount, (index) {
                final isExpanded = widget.activeIndex == index;
                final width = isExpanded ? expandedWidth : collapsedWidth;
                final title = widget.titles[index];
                final icon = widget.icons[index];
                final showAlphabet =
                    widget.alphabetModePanelIndex == index &&
                    widget.alphabetPanelBuilder != null;
                final isLast = index == widget.panelCount - 1;
                final hasBeenMounted = _mountedPanels.contains(index);

                final baseColor = widget.colors[index];

                final panelContent = Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showAlphabet)
                      SizedBox(
                        width: collapsedWidth - 2.0,
                        child: widget.alphabetPanelBuilder!(index),
                      )
                    else if (widget.tabBuilder != null)
                      SizedBox(
                        width: collapsedWidth - 2.0,
                        child: widget.tabBuilder!(index, isExpanded),
                      )
                    else
                      ExcludeFocus(
                        child: InkWell(
                          onTap: () => widget.onPanelTap(index),
                          child: SizedBox(
                            width: collapsedWidth - 2.0,
                            child: CollapsedPanelTabPreview(
                              title: title,
                              icon: icon,
                            ),
                          ),
                        ),
                      ),
                    if (hasBeenMounted)
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, innerConstraints) {
                            final offstage =
                                !isExpanded || innerConstraints.maxWidth < 180;
                            final exclude =
                                !isExpanded ||
                                widget.alphabetModePanelIndex != null;
                            var content = widget.buildExpandedContent(
                              index,
                              title,
                            );
                            if (widget.fixedContentWidth) {
                              content = OverflowBox(
                                alignment: Alignment.topLeft,
                                minWidth: contentWidth,
                                maxWidth: contentWidth,
                                child: content,
                              );
                            }
                            // Un panel cerrado queda armado (conserva su
                            // estado) pero sin foco ni animaciones.
                            return Offstage(
                              offstage: offstage,
                              child: TickerMode(
                                enabled: isExpanded,
                                child: ExcludeFocus(
                                  excluding: exclude,
                                  child: ClipRect(child: content),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: width,
                  margin: EdgeInsets.only(right: isLast ? 0 : gap),
                  decoration: glass
                      ? null
                      : BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isExpanded
                                ? borderExpanded
                                : borderCollapsed,
                          ),
                        ),
                  child: glass
                      ? MoaiGlass(
                          borderRadius: 16,
                          solid: true,
                          elevated: false,
                          child: panelContent,
                        )
                      : panelContent,
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
