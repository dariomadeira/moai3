part of '../tv_gamepad_config_dialog.dart';

/// Tarjeta que representa un gamepad físico conectado
class _GamepadDeviceCard extends StatelessWidget {
  final int index;
  final GamepadDeviceInfo device;
  final Decoration? decoration;

  const _GamepadDeviceCard({
    required this.index,
    required this.device,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final baseColor = scheme.surface.withValues(alpha: 0.8);
    final endColor = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.05),
      baseColor,
    );
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.2);

    final effectiveDecoration = decoration ??
        BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
            colors: [baseColor, baseColor, endColor],
            stops: const [0.0, 0.62, 1.0],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: effectiveDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              MoaiIcons.gamepad,
              size: MoaiIconSizes.md,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      LocaleKeys.gamepad_controller_label.tr(
                        namedArgs: {'index': '$index'},
                      ),
                      style: MoaiText.body(
                        context,
                        color: scheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        LocaleKeys.common_active.tr(),
                        style: MoaiText.body(
                          context,
                          color: scheme.onTertiaryContainer,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurface,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
