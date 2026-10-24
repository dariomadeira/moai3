part of '../tv_gamepad_config_dialog.dart';

/// Botón en squircle con animación de escala, iluminación reactiva y glow en tiempo real
class _SquircleButton extends StatelessWidget {
  final String? label;
  final String? subtitle;
  final IconData? icon;
  final bool isPressed;
  final double? height;
  final double? size;
  final Color? activeColor;

  const _SquircleButton({
    this.label,
    this.subtitle,
    this.icon,
    required this.isPressed,
    this.height,
    this.size,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final h = size ?? height ?? 40.0;

    final effectiveActiveColor = activeColor ?? scheme.primary;

    final bg = isPressed
        ? effectiveActiveColor
        : scheme.surfaceContainerHighest.withValues(alpha: 0.55);

    final fg = isPressed
        ? Colors.white
        : scheme.onSurface;

    return AnimatedScale(
      scale: isPressed ? 0.90 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutQuad,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: size,
        height: h,
        padding: size != null ? null : const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPressed
                ? effectiveActiveColor.withValues(alpha: 0.9)
                : scheme.outlineVariant.withValues(alpha: 0.35),
            width: isPressed ? 1.5 : 1.0,
          ),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: effectiveActiveColor.withValues(alpha: 0.45),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(
                icon,
                size: (size != null ? size! * 0.52 : MoaiIconSizes.md),
                color: fg,
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label ?? '',
                    style: MoaiText.body(
                      context,
                      color: fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 3),
                    Text(
                      '·$subtitle',
                      style: MoaiText.body(
                        context,
                        color: isPressed
                            ? Colors.white.withValues(alpha: 0.8)
                            : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
