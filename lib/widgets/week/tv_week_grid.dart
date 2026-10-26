import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Piezas de la grilla semanal de 7 columnas que comparten la Agenda
/// (eventos) y Descuentos: columna de un día, botón del encabezado y chip de
/// estado de las tarjetas. El contenido de cada tarjeta lo pone quien la usa.

/// Columna de un día: encabezado de cristal (día de la semana, número y
/// cuántos hay) y debajo sus tarjetas en una ventana de [windowSize] con
/// flechas si hay más, o un pozo con [emptyIcon] y [emptyText] si no hay.
///
/// Hoy va teñido del acento y la columna con foco lleva el borde del acento
/// en el encabezado (mismo criterio que TvTile).
class TvWeekDayColumn extends StatelessWidget {
  const TvWeekDayColumn({
    super.key,
    required this.weekdayLabel,
    required this.dayNumber,
    required this.isToday,
    required this.itemCount,
    required this.isColumnFocused,
    required this.selectedIndex,
    required this.windowStart,
    required this.windowSize,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyText,
    required this.onSelectColumn,
  });

  /// "LUN", "MAR"…
  final String weekdayLabel;
  final int dayNumber;
  final bool isToday;
  final int itemCount;
  final bool isColumnFocused;

  /// Tarjeta elegida (índice global).
  final int selectedIndex;
  final int windowStart;
  final int windowSize;

  /// Tarjeta [index] con su alto; [isFocused] si es la elegida y la columna
  /// tiene el foco.
  final Widget Function(
    BuildContext context,
    int index,
    bool isFocused,
    double height,
  )
  itemBuilder;
  final IconData emptyIcon;
  final String emptyText;
  final VoidCallback onSelectColumn;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final headerDayNameColor = isToday
        ? scheme.primary
        : scheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onSelectColumn,
          child: MoaiGlass(
            borderRadius: 12,
            elevated: false,
            solid: true,
            focused: isColumnFocused,
            tint: isToday ? scheme.primary : null,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 7),
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      weekdayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MoaiText.body(
                        context,
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
                        color: headerDayNameColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dayNumber',
                      style: MoaiText.display(
                        context,
                        fontSize: 15,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                if (itemCount > 0)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: moaiGlassChipDecoration(
                        scheme,
                        highlighted: isToday || isColumnFocused,
                      ),
                      child: Text(
                        '$itemCount',
                        textAlign: TextAlign.center,
                        style: MoaiText.body(
                          context,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isToday || isColumnFocused
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: itemCount == 0
              ? _buildEmptyState(context)
              : _buildWindowedList(context),
        ),
      ],
    );
  }

  Widget _buildWindowedList(BuildContext context) {
    const gap = 6.0;
    final start = windowStart.clamp(
      0,
      (itemCount - windowSize).clamp(0, itemCount),
    );
    final count = (itemCount - start).clamp(0, windowSize);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final hasMore = itemCount > windowSize;

        List<Widget> cards(double slotHeight) => List.generate(count, (i) {
          final index = start + i;
          return Padding(
            padding: EdgeInsets.only(bottom: i < count - 1 ? gap : 0),
            child: itemBuilder(
              context,
              index,
              isColumnFocused && selectedIndex == index,
              slotHeight,
            ),
          );
        });

        // Si no hay más tarjetas que el tamaño de ventana, se usa toda la
        // altura.
        if (!hasMore) {
          final slotHeight =
              (totalHeight - ((windowSize - 1) * gap)) / windowSize;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: cards(slotHeight.clamp(30.0, 150.0)),
          );
        }

        // Con más: se reserva lugar arriba y abajo para las flechas.
        const indicatorAreaHeight = 22.0;
        final availableHeight = totalHeight - (indicatorAreaHeight * 2);
        final slotHeight =
            (availableHeight - ((windowSize - 1) * gap)) / windowSize;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: indicatorAreaHeight,
              child: start > 0
                  ? const _MoreArrow(icon: MoaiIcons.chevronUp, top: true)
                  : null,
            ),
            ...cards(slotHeight.clamp(30.0, 150.0)),
            SizedBox(
              height: indicatorAreaHeight,
              child: start + windowSize < itemCount
                  ? const _MoreArrow(icon: MoaiIcons.chevronDown, top: false)
                  : null,
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final scheme = context.scheme;
    final isFocused = isColumnFocused;
    final dark = scheme.brightness == Brightness.dark;
    final line = dark ? Colors.white : scheme.onSurface;
    final contentColor = isFocused
        ? scheme.onSurface
        : scheme.onSurfaceVariant.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: onSelectColumn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        // Pozo de cristal; con foco, el borde del acento se pinta encima
        // (no ocupa espacio) y el relleno toma un tinte suave.
        decoration: BoxDecoration(
          color: isFocused
              ? scheme.primary.withValues(alpha: dark ? 0.08 : 0.06)
              : line.withValues(alpha: dark ? 0.03 : 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: line.withValues(alpha: 0.08)),
        ),
        foregroundDecoration: isFocused
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.primary, width: 2),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: MoaiIconSizes.lg,
              color: isFocused ? scheme.primary : contentColor,
            ),
            const SizedBox(height: 8),
            Text(
              emptyText,
              textAlign: TextAlign.center,
              style: MoaiText.body(
                context,
                fontSize: 11,
                fontWeight: isFocused ? FontWeight.w700 : FontWeight.w500,
                color: contentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flecha de "hay más" arriba o abajo de la columna.
class _MoreArrow extends StatelessWidget {
  const _MoreArrow({required this.icon, required this.top});

  final IconData icon;
  final bool top;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Center(
      child: Container(
        margin: EdgeInsets.only(bottom: top ? 2 : 0, top: top ? 0 : 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: moaiGlassChipDecoration(scheme, highlighted: true),
        child: Icon(icon, size: MoaiIconSizes.xs, color: scheme.primary),
      ),
    );
  }
}

/// Botón del encabezado de la semana: cristal en reposo y, con foco, acento
/// con brillo arriba y halo. Ninguno de los dos estados ocupa borde, así que
/// el tamaño no cambia.
class TvWeekHeaderButton extends StatelessWidget {
  const TvWeekHeaderButton({
    super.key,
    required this.icon,
    required this.isFocused,
    required this.onTap,
    this.label,
    this.tooltip,
    this.isLoading = false,
  });

  final IconData icon;
  final String? label;
  final String? tooltip;
  final bool isFocused;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final fgColor = isFocused ? scheme.onPrimary : scheme.onSurface;
    const radius = 12.0;
    final padding = EdgeInsets.symmetric(
      horizontal: label != null ? 12 : 10,
      vertical: 8,
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(strokeWidth: 2, color: fgColor),
          )
        else
          Icon(icon, size: MoaiIconSizes.sm, color: fgColor),
        if (label != null) ...[
          const SizedBox(width: 6),
          Text(
            label!,
            style: MoaiText.body(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fgColor,
            ),
          ),
        ],
      ],
    );

    return Tooltip(
      message: tooltip ?? label ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: isFocused
            ? Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(scheme.primary, Colors.white, 0.22)!,
                      scheme.primary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.40),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: content,
              )
            : MoaiGlass(
                borderRadius: radius,
                elevated: false,
                padding: padding,
                child: content,
              ),
      ),
    );
  }
}

enum TvWeekChipStyle { neutral, highlighted, live }

/// Micro-etiqueta de estado de una tarjeta (FIN / PRONTO / EN VIVO / la
/// provincia de una promo).
class TvWeekStatusChip extends StatelessWidget {
  const TvWeekStatusChip({
    super.key,
    required this.label,
    this.style = TvWeekChipStyle.neutral,
  });

  final String label;
  final TvWeekChipStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isLive = style == TvWeekChipStyle.live;

    final decoration = switch (style) {
      TvWeekChipStyle.neutral => moaiGlassChipDecoration(scheme, radius: 5),
      TvWeekChipStyle.highlighted => moaiGlassChipDecoration(
        scheme,
        radius: 5,
        highlighted: true,
      ),
      // En vivo: pleno del acento, lo único sólido de la grilla.
      TvWeekChipStyle.live => BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.transparent),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(scheme.primary, Colors.white, 0.18)!,
            scheme.primary,
          ],
        ),
      ),
    };

    final color = switch (style) {
      TvWeekChipStyle.neutral => scheme.onSurfaceVariant,
      TvWeekChipStyle.highlighted => scheme.primary,
      TvWeekChipStyle.live => scheme.onPrimary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: decoration,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: MoaiText.body(
              context,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
