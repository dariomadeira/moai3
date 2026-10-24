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

    final baseColor = isFocused ? scheme.primary : scheme.surfaceContainerHigh;
    final borderColor = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.55)
        : scheme.outlineVariant.withValues(alpha: 0.35);
    final fgColor = isFocused ? scheme.onPrimary : scheme.onSurface;

    return Tooltip(
      message: tooltip ?? label ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: label != null ? 12 : 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fgColor,
                  ),
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
          ),
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
    return GestureDetector(
      onTap: onTap,
      child: child,
    );
  }
}

/// Columna de un día de la semana.
