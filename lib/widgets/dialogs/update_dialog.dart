import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/services/update_service.dart';
import 'package:moai3/theme/moai_text.dart';

enum UpdateDialogState { idle, downloading, installing, error }

/// Diálogo modal interactivo para Android TV que muestra la disponibilidad
/// de una nueva versión, progreso de descarga e inicio de instalación.
class UpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<void> show(BuildContext context, AppUpdateInfo info) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      pageBuilder: (context, _, _) => UpdateDialog(updateInfo: info),
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
          _errorMessage = 'No se pudo abrir el instalador del sistema.';
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

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 520,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 36,
                spreadRadius: 8,
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
                      Symbols.system_update_rounded,
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
                          'Actualización disponible',
                          style: MoaiText.display(
                            context,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'Versión ${widget.updateInfo.version}',
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
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Contenido dinámico según estado
              if (_state == UpdateDialogState.idle) ...[
                Text(
                  'Novedades:',
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
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DialogButton(
                      focusNode: _cancelBtnFocus,
                      label: 'Más tarde',
                      isPrimary: false,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    _DialogButton(
                      focusNode: _updateBtnFocus,
                      label: 'Actualizar ahora',
                      isPrimary: true,
                      onPressed: _startDownload,
                    ),
                  ],
                ),
              ] else if (_state == UpdateDialogState.downloading) ...[
                Text(
                  'Descargando actualización...',
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
                      _progress >= 0 ? '${(_progress * 100).toInt()}%' : 'Descargando...',
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
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: _DialogButton(
                    focusNode: _cancelBtnFocus,
                    label: 'Cancelar',
                    isPrimary: false,
                    onPressed: _cancelDownload,
                  ),
                ),
              ] else if (_state == UpdateDialogState.installing) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Abriendo el instalador del sistema...',
                          style: MoaiText.body(
                            context,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sigue las instrucciones en pantalla para completar la instalación.',
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
                ),
              ] else if (_state == UpdateDialogState.error) ...[
                Container(
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
                              : 'Ocurrió un error al descargar la actualización.',
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
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DialogButton(
                      focusNode: _cancelBtnFocus,
                      label: 'Cerrar',
                      isPrimary: false,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    _DialogButton(
                      focusNode: _retryBtnFocus,
                      label: 'Reintentar',
                      isPrimary: true,
                      onPressed: _startDownload,
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

class _DialogButton extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.focusNode,
    required this.label,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
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
      bgColor = _isFocused ? scheme.surfaceContainerHighest : Colors.transparent;
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
                  : (widget.isPrimary ? Colors.transparent : scheme.outlineVariant.withValues(alpha: 0.5)),
              width: 1.5,
            ),
          ),
          child: Text(
            widget.label,
            style: MoaiText.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: fgColor,
            ),
          ),
        ),
      ),
    );
  }
}
