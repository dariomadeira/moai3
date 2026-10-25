part of '../calendar_events_panel.dart';

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String? tooltip;
  final bool isFocused;
  final bool isLoading;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.icon,
    this.label,
    this.tooltip,
    required this.isFocused,
    this.isLoading = false,
    required this.onTap,
  });

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

    // Como el botón de volver: cristal en reposo y, con foco, acento con
    // brillo arriba y halo. Ninguno de los dos estados ocupa borde, así que
    // el tamaño no cambia.
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

/// Escala al pulsar (click o D-pad). Mismo criterio que [TvTile].
class _PressScale extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool pressed;

  const _PressScale({
    required this.child,
    required this.onTap,
    this.pressed = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: child);
  }
}

/// Columna de un día de la semana.
