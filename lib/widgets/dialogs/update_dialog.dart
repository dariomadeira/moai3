import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/services/update_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';

enum UpdateDialogState { idle, downloading, installing, error }

/// Diálogo modal interactivo para Android TV que muestra la disponibilidad
/// de una nueva versión, progreso de descarga e inicio de instalación.
class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

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
          _errorMessage = 'update_error_installer'.tr();
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

  void _cancelDownload() {
    _cancelled = true;
    setState(() {
      _state = UpdateDialogState.idle;
      _progress = 0.0;
    });
    _updateBtnFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget? content;
    List<Widget>? actions;

    if (_state == UpdateDialogState.idle) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'update_changelog_title'.tr(),
            style: MoaiText.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              child: Text(
                widget.updateInfo.changelog,
                style: MoaiText.body(
                  context,
                  fontSize: 12,
                  height: 1.3,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      );
      actions = [
        TvDialogButton(
          focusNode: _cancelBtnFocus,
          label: 'update_action_later'.tr(),
          variant: TvDialogButtonVariant.neutral,
          onKeyRight: () => _updateBtnFocus.requestFocus(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 12),
        TvDialogButton(
          focusNode: _updateBtnFocus,
          label: 'update_action_update_now'.tr(),
          variant: TvDialogButtonVariant.primary,
          onKeyLeft: () => _cancelBtnFocus.requestFocus(),
          onPressed: _startDownload,
        ),
      ];
    } else if (_state == UpdateDialogState.downloading) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'update_downloading'.tr(),
            style: MoaiText.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress >= 0 ? _progress : null,
              minHeight: 10,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _progress >= 0
                    ? '${(_progress * 100).toInt()}%'
                    : 'update_downloading_progress'.tr(),
                style: MoaiText.body(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              if (_totalBytes > 0)
                Text(
                  '${(_receivedBytes / (1024 * 1024)).toStringAsFixed(1)} / ${(_totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                  style: MoaiText.body(
                    context,
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      );
      actions = [
        TvDialogButton(
          focusNode: _cancelBtnFocus,
          label: 'common_cancel'.tr(),
          variant: TvDialogButtonVariant.neutral,
          onPressed: _cancelDownload,
        ),
      ];
    } else if (_state == UpdateDialogState.installing) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'update_installing_title'.tr(),
                style: MoaiText.body(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'update_installing_desc'.tr(),
                textAlign: TextAlign.center,
                style: MoaiText.body(
                  context,
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_state == UpdateDialogState.error) {
      content = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Symbols.error, color: scheme.error, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'update_error_default'.tr(),
                style: MoaiText.body(
                  context,
                  fontSize: 12,
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      );
      actions = [
        TvDialogButton(
          focusNode: _cancelBtnFocus,
          label: 'common_close'.tr(),
          variant: TvDialogButtonVariant.neutral,
          onKeyRight: () => _retryBtnFocus.requestFocus(),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 12),
        TvDialogButton(
          focusNode: _retryBtnFocus,
          label: 'update_action_retry'.tr(),
          variant: TvDialogButtonVariant.primary,
          onKeyLeft: () => _cancelBtnFocus.requestFocus(),
          onPressed: _startDownload,
        ),
      ];
    }

    return TvDialog(
      width: 520,
      icon: Symbols.browser_updated,
      title: 'update_available_title'.tr(),
      subtitleWidget: Row(
        children: [
          Text(
            'update_available_version'.tr(
              namedArgs: {'version': widget.updateInfo.version},
            ),
            style: MoaiText.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.primary,
            ),
          ),
          if (widget.updateInfo.formattedSize.isNotEmpty) ...[
            Text(
              ' • ${widget.updateInfo.formattedSize}',
              style: MoaiText.body(
                context,
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      content: content,
      actions: actions,
    );
  }
}
