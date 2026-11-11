import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/collapsed_panel_tab_preview.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Acordeón horizontal TV: un panel expandido + tabs colapsados.
/// Conserva el estado y foco de los paneles montados al alternar entre pestañas.
class TvAccordionRowPreview extends StatefulWidget {
  final int panelCount;
  final int activeIndex;
  final List<String> titles;
  final List<IconData> icons;

  /// Íconos en SVG por panel (null: el de [icons]); para los que no están en
  /// `hugeicons_plus` (Series).
  final List<String?>? svgIcons;
  final int? alphabetModePanelIndex;
  final Widget Function(int panelIndex)? alphabetPanelBuilder;
  final Widget Function(int index, bool isExpanded)? tabBuilder;
  final ValueChanged<int> onPanelTap;
  final Widget Function(int index, String title) buildExpandedContent;

  /// El contenido se arma siempre con su ancho final ([contentWidth]): mientras
  /// el panel anima su ancho, el recorte lo descubre como una cortina en vez
  /// de re-layoutearlo cuadro a cuadro.
  final bool fixedContentWidth;

  /// Paneles de cristal esmerilado (el fondo de la app desenfocado a
  /// través). Dentro de algo que ya es de ese cristal (un diálogo) va
  /// `false`: el cristal más blanco de las tarjetas del Inicio, sin vidrio
  /// sobre vidrio.
  final bool frostedPanels;

  static const double collapsedWidth = 44.0;
  static const double gap = 6.0;

  const TvAccordionRowPreview({
    super.key,
    required this.panelCount,
    required this.activeIndex,
    required this.titles,
    required this.icons,
    this.svgIcons,
    this.alphabetModePanelIndex,
    this.alphabetPanelBuilder,
    this.tabBuilder,
    required this.onPanelTap,
    required this.buildExpandedContent,
    this.fixedContentWidth = false,
    this.frostedPanels = true,
  });

  /// Ancho del contenido del panel abierto: el panel menos su pestaña (el
  /// cristal no tiene borde que restar).
  static double contentWidth({
    required double totalWidth,
    required int panelCount,
  }) {
    final expanded = totalWidth - (collapsedWidth + gap) * (panelCount - 1);
    final width = expanded - collapsedWidth;
    return width < 0 ? 0 : width;
  }

  @override
  State<TvAccordionRowPreview> createState() => _TvAccordionRowPreviewState();
}

class _TvAccordionRowPreviewState extends State<TvAccordionRowPreview>
    with SingleTickerProviderStateMixin {
  final Set<int> _mountedPanels = {};

  /// Una sola animación reparte el ancho. Antes cada panel animaba el suyo
  /// por su cuenta y, al pasar rápido de panel, las animaciones cortadas a
  /// mitad dejaban la suma más ancha o más angosta que la pantalla: la fila
  /// entera iba y venía unos píxeles (se veía temblar el fondo). Ahora cada
  /// panel tiene un peso de apertura y los pesos suman siempre 1, así la
  /// suma de los anchos es siempre la misma.
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 1,
  );

  /// Pesos al empezar la animación en curso (suman 1).
  late List<double> _from = _oneHot(widget.activeIndex);

  List<double> _oneHot(int index) =>
      List<double>.generate(widget.panelCount, (i) => i == index ? 1.0 : 0.0);

  /// Pesos de este cuadro: de [_from] al panel activo.
  List<double> get _weights {
    final t = Curves.easeOutCubic.transform(_open.value);
    return List<double>.generate(widget.panelCount, (i) {
      final to = i == widget.activeIndex ? 1.0 : 0.0;
      final from = i < _from.length ? _from[i] : 0.0;
      return from + (to - from) * t;
    });
  }

  @override
  void initState() {
    super.initState();
    _mountedPanels.add(widget.activeIndex);
  }

  @override
  void didUpdateWidget(covariant TvAccordionRowPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _mountedPanels.add(widget.activeIndex);
    if (oldWidget.panelCount != widget.panelCount) {
      _from = _oneHot(widget.activeIndex);
      _open.value = 1;
    } else if (oldWidget.activeIndex != widget.activeIndex) {
      // Arranca desde donde esté (aunque la anterior no haya terminado).
      final t = Curves.easeOutCubic.transform(_open.value);
      _from = List<double>.generate(widget.panelCount, (i) {
        final to = i == oldWidget.activeIndex ? 1.0 : 0.0;
        return _from[i] + (to - _from[i]) * t;
      });
      if (MediaQuery.disableAnimationsOf(context)) {
        _open.value = 1;
      } else {
        _open.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
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

        final contentWidth = TvAccordionRowPreview.contentWidth(
          totalWidth: totalWidth,
          panelCount: widget.panelCount,
        );

        final extra = (expandedWidth - collapsedWidth).clamp(
          0.0,
          double.infinity,
        );

        // El contenido se arma una vez; la animación sólo cambia los anchos
        // (los mismos widgets no se vuelven a construir cuadro a cuadro).
        final panels = List<Widget>.generate(
          widget.panelCount,
          (index) => _panel(index, contentWidth: contentWidth),
        );

        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: _open,
            builder: (context, _) {
              final weights = _weights;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < widget.panelCount; i++)
                      Container(
                        width: collapsedWidth + extra * weights[i],
                        margin: EdgeInsets.only(
                          right: i == widget.panelCount - 1 ? 0 : gap,
                        ),
                        child: panels[i],
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Un panel sin su ancho (lo pone la animación).
  Widget _panel(int index, {required double contentWidth}) {
    final isExpanded = widget.activeIndex == index;
    const tabWidth = TvAccordionRowPreview.collapsedWidth;
    final title = widget.titles[index];
    final icon = widget.icons[index];
    final showAlphabet =
        widget.alphabetModePanelIndex == index &&
        widget.alphabetPanelBuilder != null;
    final hasBeenMounted = _mountedPanels.contains(index);

    final panelContent = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showAlphabet)
          SizedBox(width: tabWidth, child: widget.alphabetPanelBuilder!(index))
        else if (widget.tabBuilder != null)
          SizedBox(
            width: tabWidth,
            child: widget.tabBuilder!(index, isExpanded),
          )
        else
          ExcludeFocus(
            child: InkWell(
              onTap: () => widget.onPanelTap(index),
              child: SizedBox(
                width: tabWidth,
                child: CollapsedPanelTabPreview(
                  title: title,
                  icon: icon,
                  svgIcon: widget.svgIcons?.elementAtOrNull(index),
                ),
              ),
            ),
          ),
        if (hasBeenMounted)
          Expanded(
            child: LayoutBuilder(
              builder: (context, innerConstraints) {
                final offstage = !isExpanded || innerConstraints.maxWidth < 180;
                final exclude =
                    !isExpanded || widget.alphabetModePanelIndex != null;
                var content = widget.buildExpandedContent(index, title);
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
                      child: ClipRect(
                        clipper: const _ClipRightEdge(),
                        child: content,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );

    return MoaiGlass(
      borderRadius: MoaiGlass.panelRadius,
      solid: true,
      elevated: false,
      frosted: widget.frostedPanels,
      child: panelContent,
    );
  }
}

/// Recorta sólo el borde derecho del contenido: al cerrarse el panel, lo
/// que no entra no se sale hacia el panel vecino. Arriba, abajo y a la
/// izquierda no corta (eso ya lo limita el panel redondeado): la sombra de
/// una tarjeta de adentro se ve entera.
class _ClipRightEdge extends CustomClipper<Rect> {
  const _ClipRightEdge();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-size.width, -size.height, size.width, size.height * 2);

  @override
  bool shouldReclip(_ClipRightEdge oldClipper) => false;
}
