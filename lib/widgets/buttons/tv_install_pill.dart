import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Píldora de estado y acción para instalación de extensiones/plugins.
///
/// Iconografía:
/// - [MoaiIcons.installPending] para descarga / instalación pendiente.
/// - [MoaiIcons.checkCircle] para estado descargado / instalado.
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
    // Cristal: "Instalar" es la acción (acento con brillo); "Instalado" es un
    // estado tranquilo (cristal tenue con el tilde en el acento).
    final glass = MoaiGlassScope.enabledOf(context);
    final dark = scheme.brightness == Brightness.dark;
    final glassLine = dark ? Colors.white : scheme.onSurface;

    final Color bg;
    final Color fg;

    if (glass) {
      bg = isInstalled
          ? glassLine.withValues(alpha: dark ? 0.06 : 0.08)
          : scheme.primary;
      fg = isInstalled ? scheme.onSurface : scheme.onPrimary;
    } else if (isInstalled) {
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
        ? MoaiIcons.checkCircle
        : MoaiIcons.installPending;

    final label = isInstalled
        ? (installedLabel ?? LocaleKeys.common_installed.tr())
        : (installLabel ?? LocaleKeys.common_install.tr());

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
                Icon(
                  iconData,
                  size: MoaiIconSizes.sm,
                  color: glass && isInstalled ? scheme.primary : fg,
                ),
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

    final Decoration? glassDecoration = !glass
        ? null
        : BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: isInstalled
                ? Border.all(color: glassLine.withValues(alpha: 0.14))
                : null,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isInstalled
                  ? [bg, bg]
                  : [Color.lerp(bg, Colors.white, 0.15)!, bg],
            ),
          );

    if (glassDecoration != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: glassDecoration,
          child: onPressed != null
              ? InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(20),
                  child: content,
                )
              : content,
        ),
      );
    }

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
