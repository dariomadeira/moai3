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

    final fg = isPressed ? Colors.white : scheme.onSurface;

    // En reposo: el vidrio blanco con filo de luz de los botones de cristal.
    // Presionada: el color del botón con brillo y halo (como un botón con
    // foco). Misma forma en los dos estados para que la animación no titile.
    final decoration = moaiGlassButtonDecoration(
      scheme,
      focused: isPressed,
      accent: effectiveActiveColor,
      radius: 12,
    );

    return AnimatedScale(
      scale: isPressed ? 0.90 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutQuad,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: size,
        height: h,
        padding: size != null
            ? null
            : const EdgeInsets.symmetric(horizontal: 14),
        decoration: decoration,
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
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
                            : scheme.onSurfaceVariant,
                        fontSize: MoaiText.sizeCaption,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
