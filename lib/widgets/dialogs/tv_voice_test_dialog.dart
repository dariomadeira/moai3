import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/services/remote_voice_test_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';

/// Diálogo de prueba empírica para verificar la captura de audio
/// desde el micrófono del control remoto en Android TV.
class TvVoiceTestDialog extends StatefulWidget {
  const TvVoiceTestDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'TvVoiceTestDialog',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, _) => const TvVoiceTestDialog(),
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  @override
  State<TvVoiceTestDialog> createState() => _TvVoiceTestDialogState();
}

class _TvVoiceTestDialogState extends State<TvVoiceTestDialog> {
  bool _isLoading = true;
  bool _hasPermission = false;
  List<Map<String, dynamic>> _devices = [];
  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  String? _recordedPath;
  String? _statusMessage;
  bool _isError = false;

  final _recordFocus = FocusNode(debugLabel: 'mic_test_record');
  final _playFocus = FocusNode(debugLabel: 'mic_test_play');
  final _closeFocus = FocusNode(debugLabel: 'mic_test_close');

  @override
  void initState() {
    super.initState();
    RemoteVoiceTestService.initialize();
    RemoteVoiceTestService.onPlaybackFinished = () {
      if (mounted) {
        setState(() => _isPlaying = false);
      }
    };
    _initDiagnostic();
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    RemoteVoiceTestService.stopPlayback();
    _recordFocus.dispose();
    _playFocus.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  Future<void> _initDiagnostic() async {
    setState(() => _isLoading = true);
    final hasPerm = await RemoteVoiceTestService.hasPermission();
    final hw = await RemoteVoiceTestService.checkHardware();

    final rawDevices = hw['devices'] as List<dynamic>? ?? [];
    final devicesList = rawDevices
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _hasPermission = hasPerm;
      _devices = devicesList;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _recordFocus.canRequestFocus) {
        _recordFocus.requestFocus();
      }
    });
  }

  Future<void> _requestPermission() async {
    await RemoteVoiceTestService.requestPermission();
    await Future.delayed(const Duration(milliseconds: 600));
    final hasPerm = await RemoteVoiceTestService.hasPermission();
    if (!mounted) return;
    setState(() => _hasPermission = hasPerm);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!_hasPermission) {
      await _requestPermission();
      if (!_hasPermission) {
        setState(() {
          _isError = true;
          _statusMessage = 'Permiso RECORD_AUDIO denegado por el sistema.';
        });
        return;
      }
    }

    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
      _statusMessage = 'Grabando... Habla hacia la punta del control remoto.';
      _isError = false;
    });

    final res = await RemoteVoiceTestService.startRecording();
    if (res['success'] != true) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isError = true;
        _statusMessage = 'Error al iniciar grabación: ${res['error']}';
      });
      return;
    }

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _recordSeconds++);
      // Auto-stop a los 6 segundos para mayor comodidad en TV
      if (_recordSeconds >= 6) {
        _stopRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;

    final res = await RemoteVoiceTestService.stopRecording();
    if (!mounted) return;

    if (res['success'] == true) {
      final bytes = res['sizeBytes'] as int? ?? 0;
      final path = res['path'] as String? ?? '';
      setState(() {
        _isRecording = false;
        _recordedPath = path;
        if (bytes > 1024) {
          _isError = false;
          _statusMessage =
              'Grabación exitosa: ${(bytes / 1024).toStringAsFixed(1)} KB (AAC 16 kHz Mono). ¡Dale a reproducir!';
        } else {
          _isError = true;
          _statusMessage =
              'El archivo se creó pero tiene solo $bytes bytes. Es posible que el control no haya enviado paquetes de voz.';
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _playFocus.canRequestFocus) {
          _playFocus.requestFocus();
        }
      });
    } else {
      setState(() {
        _isRecording = false;
        _isError = true;
        _statusMessage = 'Fallo al detener: ${res['error']}';
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await RemoteVoiceTestService.stopPlayback();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      final res = await RemoteVoiceTestService.playRecording();
      if (!mounted) return;
      if (res['success'] != true) {
        setState(() {
          _isPlaying = false;
          _isError = true;
          _statusMessage = 'Error al reproducir: ${res['error']}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TvDialog(
      width: 520,
      icon: Icons.mic_outlined,
      iconBgColor: _isRecording ? scheme.error : scheme.primary,
      iconColor: _isRecording ? scheme.onError : scheme.onPrimary,
      title: 'Diagnóstico: Micrófono del Control',
      subtitle:
          'Prueba empírica de captura Voice-over-BLE por software en Android TV.',
      content: _isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Estado del hardware detectado
                _buildHardwareCard(scheme),
                const SizedBox(height: 12),

                // 2. Zona central de acción: Grabar y Reproducir
                _buildRecordingCard(scheme),

                // 3. Mensaje de estado o resultado
                if (_statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isError
                          ? scheme.errorContainer
                          : scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusMessage!,
                      style: MoaiText.body(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isError
                            ? scheme.onErrorContainer
                            : scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
      actions: [
        TvDialogButton(
          focusNode: _closeFocus,
          label: 'Cerrar',
          variant: TvDialogButtonVariant.neutral,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildHardwareCard(ColorScheme scheme) {
    final micDevices = _devices.where((d) => true).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_remote_outlined, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'Entradas de audio detectadas:',
                style: MoaiText.body(
                  context,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (micDevices.isEmpty)
            Text(
              'No se reportan entradas de audio explícitas (normal si el control BLE solo conecta por comando).',
              style: MoaiText.body(
                context,
                fontSize: 10.5,
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            ...micDevices.map((d) {
              final name = d['name'] ?? 'Desconocido';
              final typeName = d['typeName'] ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $name — $typeName',
                  style: MoaiText.body(
                    context,
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildRecordingCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          // Botón de Grabar / Detener
          Focus(
            focusNode: _recordFocus,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.space) {
                _toggleRecording();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                if (_recordedPath != null && _playFocus.canRequestFocus) {
                  _playFocus.requestFocus();
                  return KeyEventResult.handled;
                }
                _closeFocus.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Builder(
              builder: (context) {
                final isFocused = Focus.of(context).hasFocus;
                final Color bg;
                final Color fg;

                if (_isRecording) {
                  bg = scheme.error;
                  fg = scheme.onError;
                } else if (isFocused) {
                  bg = scheme.primary;
                  fg = scheme.onPrimary;
                } else {
                  bg = scheme.surfaceContainerHigh;
                  fg = scheme.onSurface;
                }

                return InkWell(
                  onTap: _toggleRecording,
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isRecording
                              ? Icons.stop_circle_outlined
                              : Icons.mic_outlined,
                          color: fg,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRecording
                              ? 'Detener grabación (${_recordSeconds}s / 6s)'
                              : 'Presionar [OK] para Grabar',
                          style: MoaiText.display(
                            context,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Botón de Reproducir (solo si hay archivo grabado)
          if (_recordedPath != null && !_isRecording) ...[
            const SizedBox(height: 10),
            Focus(
              focusNode: _playFocus,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.select ||
                    event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space) {
                  _togglePlayback();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _recordFocus.requestFocus();
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _closeFocus.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Builder(
                builder: (context) {
                  final isFocused = Focus.of(context).hasFocus;
                  final Color bg;
                  final Color fg;

                  if (_isPlaying) {
                    bg = scheme.tertiaryContainer;
                    fg = scheme.onTertiaryContainer;
                  } else if (isFocused) {
                    bg = scheme.primary;
                    fg = scheme.onPrimary;
                  } else {
                    bg = scheme.surfaceContainerHigh;
                    fg = scheme.onSurface;
                  }

                  return InkWell(
                    onTap: _togglePlayback,
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isPlaying
                                ? Icons.volume_up
                                : Icons.play_arrow_outlined,
                            color: fg,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isPlaying
                                ? 'Reproduciendo por la TV...'
                                : 'Reproducir Audio Grabado',
                            style: MoaiText.display(
                              context,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
