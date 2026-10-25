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

    final dark = scheme.brightness == Brightness.dark;
    final line = dark ? Colors.white : scheme.onSurface;

    final fg = isPressed ? Colors.white : scheme.onSurface;

    // En reposo: tecla de cristal como el teclado en pantalla. Presionada:
    // degradé del color del botón. El borde no cambia de ancho para que
    // nada se mueva.
    final decoration = isPressed
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(effectiveActiveColor, Colors.white, 0.18)!,
                effectiveActiveColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: effectiveActiveColor.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ],
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: line.withValues(alpha: dark ? 0.045 : 0.05),
            border: Border.all(color: line.withValues(alpha: 0.08)),
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
            : const EdgeInsets.symmetric(horizontal: 10),
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
