import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/services/update_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/theme/moai_icons.dart';

enum UpdateDialogState { idle, downloading, installing, error }

/// Diálogo modal interactivo para Android TV que muestra la disponibilidad
/// de una nueva versión, progreso de descarga e inicio de instalación.
class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  /// PRUEBA (2026-11-04): en debug, "Buscar actualizaciones" abre este modal
  /// con [previewInfo] en vez de consultar el servidor, y la descarga se
  /// simula (progreso → instalador → error) para ver todos los estados.
  /// Poner en false para volver al comportamiento real.
  static const bool previewInDebug = false;

  static const String _previewApkUrl = 'preview://moai.apk';

  /// Versión de mentira para [previewInDebug].
  static const AppUpdateInfo previewInfo = AppUpdateInfo(
    version: '3.1.0',
    apkUrl: _previewApkUrl,
    fileSize: 48 * 1024 * 1024,
    changelog:
        '- Nuevo diseño de cristal en toda la app\n'
        '- Buscador de películas más rápido\n'
        '- Calibración de pantalla rediseñada\n'
        '- Correcciones en el clima de pueblos chicos\n'
        '- Mejoras de rendimiento en el Chromecast',
  );

  static Future<void> show(BuildContext context, AppUpdateInfo info) {
    return showTvGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (context) => UpdateDialog(updateInfo: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  UpdateDialogState _state = UpdateDialogState.idle;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String _errorMessage = '';
  bool _cancelled = false;

  final FocusNode _updateBtnFocus = FocusNode(debugLabel: 'update_btn');
  final FocusNode _cancelBtnFocus = FocusNode(debugLabel: 'cancel_btn');
  final FocusNode _retryBtnFocus = FocusNode(debugLabel: 'retry_btn');

  bool get _isPreview =>
      widget.updateInfo.apkUrl == UpdateDialog._previewApkUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateBtnFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _updateBtnFocus.dispose();
    _cancelBtnFocus.dispose();
    _retryBtnFocus.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _state = UpdateDialogState.downloading;
      _progress = 0.0;
      _cancelled = false;
      _errorMessage = '';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cancelBtnFocus.requestFocus();
    });

    if (_isPreview) return _simulateDownload();

    try {
      final path = await UpdateService.downloadApk(
        widget.updateInfo.apkUrl,
        onProgress: (p, received, total) {
          if (mounted && !_cancelled) {
            setState(() {
              _progress = p;
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
        isCancelled: () => _cancelled,
      );

      if (_cancelled) return;

      setState(() {
        _state = UpdateDialogState.installing;
      });

      final success = await UpdateService.installApk(path);
      if (!success && mounted) {
        setState(() {
          _state = UpdateDialogState.error;
          _errorMessage = LocaleKeys.update_error_installer.tr();
        });
        _retryBtnFocus.requestFocus();
      }
    } catch (e) {
      if (_cancelled) return;
      if (mounted) {
        setState(() {
          _state = UpdateDialogState.error;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
        _retryBtnFocus.requestFocus();
      }
    }
  }

  /// PRUEBA: descarga de mentira de [UpdateDialog.previewInfo]; recorre los
  /// estados de descarga, instalador y error.
  Future<void> _simulateDownload() async {
    final total = widget.updateInfo.fileSize ?? 0;
    const steps = 60;
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (!mounted || _cancelled) return;
      setState(() {
        _progress = i / steps;
        _receivedBytes = total * i ~/ steps;
        _totalBytes = total;
      });
    }
    setState(() => _state = UpdateDialogState.installing);
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted || _cancelled) return;
    setState(() {
      _state = UpdateDialogState.error;
      _errorMessage = LocaleKeys.update_error_installer.tr();
    });
    _retryBtnFocus.requestFocus();
  }

  void _cancelDownload() {
    _cancelled = true;
    setState(() {
      _state = UpdateDialogState.idle;
      _progress = 0.0;
    });
    _updateBtnFocus.requestFocus();
  }

  /// Líneas del changelog sin la viñeta de texto ("-", "*", "•").
  List<String> _changelogLines() {
    final lines = [
      for (final raw in widget.updateInfo.changelog.split('\n'))
        if (raw.trim().isNotEmpty)
          raw.trim().replaceFirst(RegExp(r'^[-*•]\s*'), ''),
    ];
    return lines.isEmpty ? [LocaleKeys.update_changelog_default.tr()] : lines;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMandatory = widget.updateInfo.isMandatory;

    Widget? content;
    List<Widget>? actions;

    if (_state == UpdateDialogState.idle) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMandatory) ...[
            _Notice(
              icon: MoaiIcons.warningFilled,
              text: LocaleKeys.update_mandatory_notice.tr(),
              tint: scheme.error,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            LocaleKeys.update_changelog_title.tr(),
            style: MoaiText.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          // Novedades en una ficha de cristal, con viñetas del acento.
          MoaiGlass(
            borderRadius: MoaiGlass.panelRadius,
            elevated: false,
            solid: true,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 150),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (i, line) in _changelogLines().indexed) ...[
                      if (i > 0) const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 6, right: 10),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              line,
                              style: MoaiText.body(
                                context,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      );
      actions = [
        if (!isMandatory)
          TvDialogButton(
            focusNode: _cancelBtnFocus,
            label: LocaleKeys.update_action_later.tr(),
            onKeyRight: _updateBtnFocus.requestFocus,
            onPressed: () => Navigator.of(context).pop(),
          ),
        TvDialogButton(
          focusNode: _updateBtnFocus,
          label: LocaleKeys.update_action_update_now.tr(),
          icon: MoaiIcons.appUpdate,
          variant: TvDialogButtonVariant.primary,
          onKeyLeft: !isMandatory ? _cancelBtnFocus.requestFocus : null,
          onPressed: _startDownload,
        ),
      ];
    } else if (_state == UpdateDialogState.downloading) {
      final known = _progress >= 0;
      content = MoaiGlass(
        borderRadius: MoaiGlass.panelRadius,
        elevated: false,
        solid: true,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    LocaleKeys.update_downloading.tr(),
                    style: MoaiText.body(
                      context,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  known
                      ? '${(_progress * 100).toInt()}%'
                      : LocaleKeys.update_downloading_progress.tr(),
                  style:
                      MoaiText.display(
                        context,
                        fontSize: 18,
                        color: scheme.primary,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ProgressBar(value: known ? _progress : null),
            if (_totalBytes > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${(_receivedBytes / (1024 * 1024)).toStringAsFixed(1)} / '
                '${(_totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                style: MoaiText.body(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
      actions = isMandatory
          ? null
          : [
              TvDialogButton(
                focusNode: _cancelBtnFocus,
                label: LocaleKeys.common_cancel.tr(),
                onPressed: _cancelDownload,
              ),
            ];
    } else if (_state == UpdateDialogState.installing) {
      content = MoaiGlass(
        borderRadius: MoaiGlass.panelRadius,
        elevated: false,
        solid: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                valueColor: AlwaysStoppedAnimation<Color>(
                  scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              LocaleKeys.update_installing_title.tr(),
              textAlign: TextAlign.center,
              style: MoaiText.body(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              LocaleKeys.update_installing_desc.tr(),
              textAlign: TextAlign.center,
              style: MoaiText.body(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    } else if (_state == UpdateDialogState.error) {
      content = _Notice(
        icon: MoaiIcons.errorFilled,
        text: _errorMessage.isNotEmpty
            ? _errorMessage
            : LocaleKeys.update_error_default.tr(),
        tint: scheme.error,
      );
      actions = [
        if (!isMandatory)
          TvDialogButton(
            focusNode: _cancelBtnFocus,
            label: LocaleKeys.common_close.tr(),
            onKeyRight: _retryBtnFocus.requestFocus,
            onPressed: () => Navigator.of(context).pop(),
          ),
        TvDialogButton(
          focusNode: _retryBtnFocus,
          label: LocaleKeys.update_action_retry.tr(),
          icon: MoaiIcons.pluginUpdate,
          variant: TvDialogButtonVariant.primary,
          onKeyLeft: !isMandatory ? _cancelBtnFocus.requestFocus : null,
          onPressed: _startDownload,
        ),
      ];
    }

    return PopScope(
      canPop: !isMandatory,
      child: TvDialog(
        width: 560,
        padding: const EdgeInsets.all(20),
        icon: MoaiIcons.appUpdate,
        title: isMandatory
            ? LocaleKeys.update_mandatory_title.tr()
            : LocaleKeys.update_available_title.tr(),
        // Versión, tamaño y "requerida" como los géneros de una película.
        subtitleWidget: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _Tag(
                text: LocaleKeys.update_available_version.tr(
                  namedArgs: {'version': widget.updateInfo.version},
                ),
              ),
              if (widget.updateInfo.formattedSize.isNotEmpty)
                _Tag(text: widget.updateInfo.formattedSize),
              if (isMandatory)
                _Tag(
                  text: LocaleKeys.update_mandatory_badge.tr(),
                  color: scheme.error,
                ),
            ],
          ),
        ),
        content: content,
        actions: actions,
      ),
    );
  }
}

/// Etiqueta chica (versión, tamaño, "requerida"): la misma pastilla que los
/// géneros del detalle de película (`TvMovieGenreChip`): redonda, en el acento
/// sólido y texto blanco. [color] la cambia (rojo para "requerida").
class _Tag extends StatelessWidget {
  final String text;

  /// Por defecto, el acento.
  final Color? color;

  const _Tag({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final own = color;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: own ?? scheme.primary,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        // Bajado lo justo para verse centrado (ver
        // [MoaiText.opticalCenterShift]).
        child: Transform.translate(
          offset: Offset(0, MoaiText.opticalCenterShift(12)),
          child: Text(
            text,
            style: MoaiText.body(
              context,
              fontSize: 12,
              color: own == null ? scheme.onPrimary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso teñido (obligatoria, error): etiqueta de cristal ancha con ícono.
class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color tint;

  const _Notice({required this.icon, required this.text, required this.tint});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = moaiGlassTagForeground(scheme, tint: tint);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: moaiGlassTagDecoration(
        scheme,
        tint: tint,
        radius: MoaiGlass.panelRadius,
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: MoaiIconSizes.md),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: MoaiText.body(
                context,
                fontSize: 13,
                height: 1.3,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de progreso fina con el degradado del acento; sin [value], la
/// indeterminada.
class _ProgressBar extends StatelessWidget {
  final double? value;

  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final track = scheme.onSurface.withValues(alpha: 0.08);
    final value = this.value;
    if (value == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          minHeight: 6,
          backgroundColor: track,
          valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 6,
        color: track,
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          widthFactor: value.clamp(0.0, 1.0),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(scheme.primary, Colors.white, 0.35)!,
                  scheme.primary,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
