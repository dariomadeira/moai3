part of '../tv_gamepad_config_dialog.dart';

/// Tarjeta que representa un gamepad físico conectado: ícono en el acento en una
/// etiqueta de cristal, "Mando N" con la pastilla verde "Activo" y el nombre.
class _GamepadDeviceCard extends StatelessWidget {
  final int index;
  final GamepadDeviceInfo device;

  const _GamepadDeviceCard({required this.index, required this.device});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: moaiGlassTagDecoration(scheme, radius: 12),
          child: Icon(
            MoaiIcons.gamepad,
            size: MoaiIconSizes.md,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
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
                      color: scheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TvMetaPill(
                    label: LocaleKeys.common_active.tr(),
                    tint: TvInstallPill.installedColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
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
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
