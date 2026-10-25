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

    final effectiveDecoration =
        decoration ?? moaiGlassWellDecoration(scheme, radius: 14);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: effectiveDecoration,
      child: Row(
        children: [
          // Ícono suelto en el acento, sin cuadrado (como TvTile).
          Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              MoaiIcons.gamepad,
              size: MoaiIconSizes.md,
              color: scheme.primary,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: moaiGlassChipDecoration(
                        scheme,
                        radius: 6,
                        highlighted: true,
                      ),
                      child: Text(
                        LocaleKeys.common_active.tr(),
                        style: MoaiText.body(
                          context,
                          color: scheme.primary,
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
