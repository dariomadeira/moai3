import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/services/plugin_host_service.dart';
import 'package:moai3/services/plugin_update_service.dart';
import 'package:moai3/theme/moai_text.dart';
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
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      pageBuilder: (context, _, _) => PluginUpdateDialog(updates: updates),
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
          _statusText = 'Actualizando ${update.source.nombre}...';
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
              ? '${widget.updates.first.source.nombre} actualizada con éxito.'
              : '${widget.updates.length} fuentes actualizadas con éxito.',
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

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 480,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 36,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Symbols.extension,
                      color: scheme.onPrimaryContainer,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.updates.length == 1
                              ? 'Actualización de Fuente'
                              : 'Actualizaciones de Fuentes',
                          style: MoaiText.display(
                            context,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Nueva versión disponible en el repositorio',
                          style: MoaiText.body(
                            context,
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Contenido según estado
              if (_state == _PluginUpdateState.idle) ...[
                Text(
                  'Fuentes a actualizar:',
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
                                  '${u.newChannelCount} canales organizados',
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
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DialogActionButton(
                      focusNode: _cancelBtnFocus,
                      label: 'Más tarde',
                      isPrimary: false,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    _DialogActionButton(
                      focusNode: _updateBtnFocus,
                      label: 'Actualizar ahora',
                      isPrimary: true,
                      onPressed: _startUpdate,
                    ),
                  ],
                ),
              ] else if (_state == _PluginUpdateState.updating) ...[
                Container(
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
                        'Descargando y verificando firma DEX...',
                        style: MoaiText.body(
                          context,
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_state == _PluginUpdateState.success) ...[
                Container(
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
                        '¡Actualización completada!',
                        style: MoaiText.display(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_state == _PluginUpdateState.error) ...[
                Container(
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
                              : 'Ocurrió un error al actualizar la fuente.',
                          style: MoaiText.body(
                            context,
                            fontSize: 12,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DialogActionButton(
                      focusNode: _cancelBtnFocus,
                      label: 'Cerrar',
                      isPrimary: false,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    _DialogActionButton(
                      focusNode: _retryBtnFocus,
                      label: 'Reintentar',
                      isPrimary: true,
                      onPressed: _startUpdate,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogActionButton extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _DialogActionButton({
    required this.focusNode,
    required this.label,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  State<_DialogActionButton> createState() => _DialogActionButtonState();
}

class _DialogActionButtonState extends State<_DialogActionButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final Color bgColor;
    final Color fgColor;

    if (widget.isPrimary) {
      bgColor = _isFocused ? scheme.onPrimary : scheme.primary;
      fgColor = _isFocused ? scheme.primary : scheme.onPrimary;
    } else {
      bgColor =
          _isFocused ? scheme.surfaceContainerHighest : Colors.transparent;
      fgColor = _isFocused ? scheme.onSurface : scheme.onSurfaceVariant;
    }

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isFocused
                  ? (widget.isPrimary ? scheme.primary : scheme.outline)
                  : (widget.isPrimary
                      ? Colors.transparent
                      : scheme.outlineVariant.withValues(alpha: 0.5)),
              width: 1.5,
            ),
          ),
          child: Text(
            widget.label,
            style: MoaiText.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
        ),
      ),
    );
  }
}
