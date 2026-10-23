import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';

/// Píldora de estado y acción para instalación de extensiones/plugins.
///
/// Iconografía:
/// - [MoaiIcons.installPending] para descarga / instalación pendiente.
/// - [MoaiIcons.checkCircleOutlineRounded] para estado descargado / instalado.
class TvInstallPill extends StatelessWidget {
  final bool isInstalled;
  final bool isFocused;
  final VoidCallback? onPressed;
  final String? installLabel;
  final String? installedLabel;

  final double? downloadProgress;

  const TvInstallPill({
    super.key,
    required this.isInstalled,
    this.isFocused = false,
    this.downloadProgress,
    this.onPressed,
    this.installLabel,
    this.installedLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color bg;
    final Color fg;

    if (isInstalled) {
      if (isFocused) {
        bg = scheme.onPrimary.withValues(alpha: 0.2);
        fg = scheme.onPrimary;
      } else {
        bg = scheme.tertiaryContainer;
        fg = scheme.onTertiaryContainer;
      }
    } else {
      if (isFocused) {
        bg = scheme.onPrimary;
        fg = scheme.primary;
      } else {
        bg = scheme.primary;
        fg = scheme.onPrimary;
      }
    }

    final isDownloading = downloadProgress != null;

    final iconData = isInstalled
        ? MoaiIcons.checkCircleOutlineRounded
        : MoaiIcons.installPending;

    final label = isInstalled
        ? (installedLabel ?? 'sources_status_installed'.tr())
        : (installLabel ?? 'sources_install'.tr());

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: isDownloading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: downloadProgress! > 0 ? downloadProgress : null,
                    color: fg,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(downloadProgress! * 100).toInt()}%',
                  style: MoaiText.body(
                    context,
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconData, size: 16, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: MoaiText.body(
                    context,
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: onPressed != null
          ? InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(20),
              child: content,
            )
          : content,
    );
  }
}
