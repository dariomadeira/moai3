import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/collapsed_panel_tab.dart';

/// Acordeón horizontal TV: un panel expandido + tabs colapsados (38px).
///
/// Compartido con Settings. Modelo Smart: si el ancho del contenido aún anima
/// por debajo de 180px no monta hijos (evita overflow); el foco se recupera
/// con [_requestFocusWithRetry] / [FocusScrollSync] en el caller.
class TvAccordionRow extends StatelessWidget {
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

  const TvAccordionRow({
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
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        const collapsedWidth = 38.0;
        const gap = 6.0;
        final totalGaps = gap * (panelCount - 1);
        final expandedWidth =
            totalWidth - (collapsedWidth * (panelCount - 1)) - totalGaps;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(panelCount, (index) {
              final isExpanded = activeIndex == index;
              final width = isExpanded ? expandedWidth : collapsedWidth;
              final title = titles[index];
              final icon = icons[index];
              final showAlphabet = alphabetModePanelIndex == index &&
                  alphabetPanelBuilder != null;
              final isLast = index == panelCount - 1;

              return RepaintBoundary(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: width,
                  margin: EdgeInsets.only(right: isLast ? 0 : gap),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: colors[index],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showAlphabet)
                        SizedBox(
                          width: collapsedWidth,
                          child: alphabetPanelBuilder!(index),
                        )
                      else if (tabBuilder != null)
                        SizedBox(
                          width: collapsedWidth,
                          child: tabBuilder!(index, isExpanded),
                        )
                      else
                        ExcludeFocus(
                          child: InkWell(
                            onTap: () => onPanelTap(index),
                            child: SizedBox(
                              width: collapsedWidth,
                              child: CollapsedPanelTab(
                                title: title,
                                icon: icon,
                              ),
                            ),
                          ),
                        ),
                      if (isExpanded)
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, innerConstraints) {
                              if (innerConstraints.maxWidth < 180) {
                                return const SizedBox.shrink();
                              }
                              final content = ClipRect(
                                child: buildExpandedContent(index, title),
                              );
                              // Filtro alfabético: el listado no puede robar
                              // foco ni disparar L/R de cambio de panel.
                              if (alphabetModePanelIndex != null) {
                                return ExcludeFocus(child: content);
                              }
                              return content;
                            },
                          ),
                        )
                      else
                        const Spacer(),
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

