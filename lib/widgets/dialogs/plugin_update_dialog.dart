import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/services/plugin_host_service.dart';
import 'package:moai3/services/plugin_update_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:provider/provider.dart';

enum _PluginUpdateState { idle, updating, success, error }

/// Diálogo accesible desde control remoto (Android TV) para notificar y
/// actualizar fuentes de plugins.
class PluginUpdateDialog extends StatefulWidget {
  final List<PluginUpdateInfo> updates;

  const PluginUpdateDialog({super.key, required this.updates});

  static Future<void> show(
    BuildContext context,
    List<PluginUpdateInfo> updates,
  ) {
    return showTvGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (context) => PluginUpdateDialog(updates: updates),
    );
  }

  @override
  State<PluginUpdateDialog> createState() => _PluginUpdateDialogState();
}

class _PluginUpdateDialogState extends State<PluginUpdateDialog> {
  _PluginUpdateState _state = _PluginUpdateState.idle;
  String _statusText = '';
  String _errorMessage = '';

  final FocusNode _updateBtnFocus = FocusNode(debugLabel: 'plugin_update_btn');
  final FocusNode _cancelBtnFocus = FocusNode(debugLabel: 'plugin_cancel_btn');
  final FocusNode _retryBtnFocus = FocusNode(debugLabel: 'plugin_retry_btn');

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

  Future<void> _startUpdate() async {
    setState(() {
      _state = _PluginUpdateState.updating;
      _errorMessage = '';
    });

    final controller = context.read<PluginHostController>();

    try {
      for (final update in widget.updates) {
        setState(() {
          _statusText = 'plugin_update_updating_named'.tr(
            namedArgs: {'name': update.source.nombre},
          );
        });
        await controller.updateSource(update.manifestUrl);
      }

      if (!mounted) return;

      setState(() {
        _state = _PluginUpdateState.success;
      });

      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        Navigator.of(context).pop();
        MoaiSnackBar.showSuccess(
          context,
          message: widget.updates.length == 1
              ? 'plugin_update_success_single'.tr(
                  namedArgs: {'name': widget.updates.first.source.nombre},
                )
              : 'plugin_update_success_plural'.tr(
                  namedArgs: {'count': widget.updates.length.toString()},
                ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _PluginUpdateState.error;
        _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _retryBtnFocus.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget? content;
    List<Widget>? actions;

    if (_state == _PluginUpdateState.idle) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'plugin_update_header'.tr(),
            style: MoaiText.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: widget.updates.length,
              separatorBuilder: (_, _) => Divider(
                color: scheme.outlineVariant.withValues(alpha: 0.15),
                height: 12,
              ),
              itemBuilder: (context, i) {
                final u = widget.updates[i];
                return Row(
                  children: [
                    Icon(
                      Symbols.electrical_services,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.source.nombre,
                            style: MoaiText.body(
                              context,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            'plugin_update_channels_count'.tr(
                              namedArgs: {
                                'count': u.newChannelCount.toString(),
                              },
                            ),
                            style: MoaiText.body(
                              context,
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'v${u.source.version} → v${u.remoteVersion}',
                        style: MoaiText.body(
                          context,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                );
              },
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
          onPressed: _startUpdate,
        ),
      ];
    } else if (_state == _PluginUpdateState.updating) {
      content = Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Column(
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              color: scheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _statusText,
              style: MoaiText.body(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'plugin_update_updating_status'.tr(),
              style: MoaiText.body(
                context,
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    } else if (_state == _PluginUpdateState.success) {
      content = Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              Symbols.check_circle_rounded,
              color: scheme.primary,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              'plugin_update_completed'.tr(),
              style: MoaiText.display(
                context,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      );
    } else if (_state == _PluginUpdateState.error) {
      content = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: scheme.error.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(Symbols.error, color: scheme.error, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'plugin_update_error_default'.tr(),
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
          onPressed: _startUpdate,
        ),
      ];
    }

    return TvDialog(
      width: 480,
      icon: Symbols.extension,
      title: widget.updates.length == 1
          ? 'plugin_update_title_singular'.tr()
          : 'plugin_update_title_plural'.tr(),
      subtitle: 'plugin_update_subtitle'.tr(),
      content: content,
      actions: actions,
    );
  }
}
