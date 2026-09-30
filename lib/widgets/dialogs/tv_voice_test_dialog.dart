import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/services/remote_voice_test_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';

/// Diálogo modal estándar de TV para diagnosticar el micrófono del control remoto.
///
/// Permite capturar audio vía Voice-over-BLE por software, validar la señal
/// y reproducirla por los altavoces de la televisión con amplificación digital (+18 dB).
/// Diseñado para Leanback / Android TV con accesibilidad D-Pad completa.
class TvVoiceTestDialog extends StatefulWidget {
  const TvVoiceTestDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showTvGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'TvVoiceTestDialog',
      builder: (dialogContext) => const TvVoiceTestDialog(),
    );
  }

  @override
  State<TvVoiceTestDialog> createState() => _TvVoiceTestDialogState();
}

class _TvVoiceTestDialogState extends State<TvVoiceTestDialog>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasPermission = false;
  List<Map<String, dynamic>> _devices = [];
  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  String? _recordedPath;
  int _recordedBytes = 0;
  String? _errorMessage;

  late final AnimationController _waveController;

  final _recordFocus = FocusNode(debugLabel: 'mic_test_record');
  final _playFocus = FocusNode(debugLabel: 'mic_test_play');
  final _rerecordFocus = FocusNode(debugLabel: 'mic_test_rerecord');
  final _closeFocus = FocusNode(debugLabel: 'mic_test_close');

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    RemoteVoiceTestService.initialize();
    RemoteVoiceTestService.onPlaybackFinished = () {
      if (mounted) {
        _waveController.stop();
        setState(() => _isPlaying = false);
      }
    };
    _initDiagnostic();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _recordTimer?.cancel();
    RemoteVoiceTestService.stopPlayback();
    _recordFocus.dispose();
    _playFocus.dispose();
    _rerecordFocus.dispose();
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

  Future<void> _startRecording() async {
    if (_isPlaying) {
      await RemoteVoiceTestService.stopPlayback();
      _isPlaying = false;
    }

    if (!_hasPermission) {
      await _requestPermission();
      if (!_hasPermission) {
        setState(() {
          _errorMessage = 'mic_test_perm_denied'.tr();
        });
        return;
      }
    }

    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
      _errorMessage = null;
    });
    _waveController.repeat(reverse: true);

    final res = await RemoteVoiceTestService.startRecording();
    if (res['success'] != true) {
      if (!mounted) return;
      _waveController.stop();
      setState(() {
        _isRecording = false;
        _errorMessage = 'mic_test_err_start'.tr(
          namedArgs: {'error': '${res['error'] ?? ''}'},
        );
      });
      return;
    }

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _recordSeconds++);
      if (_recordSeconds >= 6) {
        _stopRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    _waveController.stop();

    final res = await RemoteVoiceTestService.stopRecording();
    if (!mounted) return;

    if (res['success'] == true) {
      final bytes = res['sizeBytes'] as int? ?? 0;
      final path = res['path'] as String? ?? '';
      setState(() {
        _isRecording = false;
        _recordedPath = path;
        _recordedBytes = bytes;
        _errorMessage = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _playFocus.canRequestFocus) {
          _playFocus.requestFocus();
        }
      });
    } else {
      setState(() {
        _isRecording = false;
        _errorMessage = 'mic_test_err_stop'.tr(
          namedArgs: {'error': '${res['error'] ?? ''}'},
        );
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await RemoteVoiceTestService.stopPlayback();
      _waveController.stop();
      setState(() => _isPlaying = false);
    } else {
      setState(() {
        _isPlaying = true;
        _errorMessage = null;
      });
      _waveController.repeat(reverse: true);
      final res = await RemoteVoiceTestService.playRecording();
      if (!mounted) return;
      if (res['success'] != true) {
        _waveController.stop();
        setState(() {
          _isPlaying = false;
          _errorMessage = 'mic_test_err_play'.tr(
            namedArgs: {'error': '${res['error'] ?? ''}'},
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TvDialog(
      width: 580,
      icon: Icons.mic_outlined,
      iconBgColor: _isRecording
          ? scheme.error
          : _isPlaying
              ? scheme.tertiary
              : scheme.primaryContainer,
      iconColor: _isRecording
          ? scheme.onError
          : _isPlaying
              ? scheme.onTertiary
              : scheme.onPrimaryContainer,
      title: 'mic_test_title'.tr(),
      subtitle: 'mic_test_subtitle'.tr(),
      content: _isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Banner de recomendación ergonómica
                _buildTipBanner(scheme),
                const SizedBox(height: 14),

                // 2. Tarjeta interactiva central (Estado, Olas de audio y Controles)
                _buildMainCard(scheme),
                const SizedBox(height: 14),

                // 3. Ficha compacta de hardware detectado
                _buildHardwareFooter(scheme),

                // 4. Mensaje de error si ocurre alguno
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: MoaiText.body(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
      actions: [
        TvDialogButton(
          focusNode: _closeFocus,
          label: 'common_close'.tr(),
          variant: TvDialogButtonVariant.neutral,
          onKeyUp: () {
            if (_recordedPath != null && !_isRecording) {
              _playFocus.requestFocus();
            } else {
              _recordFocus.requestFocus();
            }
          },
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildTipBanner(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'mic_test_tip'.tr(),
              style: MoaiText.body(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (_isRecording)
            _buildRecordingState(scheme)
          else if (_recordedPath != null)
            _buildRecordedState(scheme)
          else
            _buildIdleState(scheme),
        ],
      ),
    );
  }

  Widget _buildIdleState(ColorScheme scheme) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mic_none_outlined,
            size: 32,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'mic_test_ready_hint'.tr(),
          style: MoaiText.body(
            context,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          focusNode: _recordFocus,
          icon: Icons.fiber_manual_record,
          label: 'mic_test_btn_record'.tr(),
          isPrimary: true,
          onPressed: _startRecording,
          onKeyDown: () => _closeFocus.requestFocus(),
        ),
      ],
    );
  }

  Widget _buildRecordingState(ColorScheme scheme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: scheme.error,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: scheme.error.withValues(alpha: 0.6),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '0:0$_recordSeconds / 0:06',
              style: MoaiText.display(
                context,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: scheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildWaveVisualizer(scheme, color: scheme.error),
        const SizedBox(height: 10),
        Text(
          'mic_test_recording_active'.tr(),
          style: MoaiText.body(
            context,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          focusNode: _recordFocus,
          icon: Icons.stop_circle_outlined,
          label: 'mic_test_btn_stop'.tr(
            namedArgs: {'seconds': '$_recordSeconds'},
          ),
          isPrimary: false,
          customBg: scheme.error,
          customFg: scheme.onError,
          onPressed: _stopRecording,
          onKeyDown: () => _closeFocus.requestFocus(),
        ),
      ],
    );
  }

  Widget _buildRecordedState(ColorScheme scheme) {
    final isAudioValid = _recordedBytes > 1024;
    final kbStr = (_recordedBytes / 1024).toStringAsFixed(1);

    return Column(
      children: [
        if (isAudioValid) ...[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'mic_test_badge_ready'.tr(),
                  style: MoaiText.body(
                    context,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.volume_up,
                      size: 14,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'mic_test_badge_amplified'.tr(),
                      style: MoaiText.body(
                        context,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isPlaying) ...[
            _buildWaveVisualizer(scheme, color: scheme.tertiary),
            const SizedBox(height: 8),
            Text(
              'mic_test_playing_active'.tr(),
              style: MoaiText.body(
                context,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
          ] else ...[
            Text(
              'mic_test_success_desc'.tr(namedArgs: {'kb': kbStr}),
              style: MoaiText.body(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ] else ...[
          Icon(Icons.warning_amber_rounded, size: 36, color: scheme.error),
          const SizedBox(height: 6),
          Text(
            'mic_test_empty_desc'.tr(
              namedArgs: {'bytes': '$_recordedBytes'},
            ),
            style: MoaiText.body(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isAudioValid) ...[
              Expanded(
                child: _buildActionButton(
                  focusNode: _playFocus,
                  icon: _isPlaying ? Icons.stop : Icons.volume_up_outlined,
                  label: _isPlaying
                      ? 'mic_test_btn_stop_play'.tr()
                      : 'mic_test_btn_play'.tr(),
                  isPrimary: true,
                  customBg: _isPlaying ? scheme.tertiary : null,
                  customFg: _isPlaying ? scheme.onTertiary : null,
                  onPressed: _togglePlayback,
                  onKeyRight: () => _rerecordFocus.requestFocus(),
                  onKeyDown: () => _closeFocus.requestFocus(),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: _buildActionButton(
                focusNode: _rerecordFocus,
                icon: Icons.refresh_outlined,
                label: 'mic_test_btn_rerecord'.tr(),
                isPrimary: !isAudioValid,
                onPressed: _startRecording,
                onKeyLeft: () {
                  if (isAudioValid) _playFocus.requestFocus();
                },
                onKeyDown: () => _closeFocus.requestFocus(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWaveVisualizer(ColorScheme scheme, {required Color color}) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        final progress = _waveController.value;
        const barHeights = [14.0, 26.0, 36.0, 22.0, 32.0, 18.0, 28.0];

        return SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barHeights.length, (index) {
              final offset = (index * 0.18) % 1.0;
              final factor = ((progress + offset) % 1.0);
              final dynamicHeight =
                  (barHeights[index] * (0.4 + 0.6 * factor)).clamp(8.0, 38.0);

              return Container(
                width: 5,
                height: dynamicHeight,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.8 + 0.2 * factor),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildHardwareFooter(ColorScheme scheme) {
    final devNames = _devices
        .map((d) => d['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final infoText = devNames.isNotEmpty
        ? devNames.join(', ')
        : 'mic_test_no_devices'.tr();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.settings_remote_outlined,
            size: 15,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${'mic_test_devices_header'.tr()}: $infoText',
              style: MoaiText.body(
                context,
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
    Color? customBg,
    Color? customFg,
    VoidCallback? onKeyLeft,
    VoidCallback? onKeyRight,
    VoidCallback? onKeyUp,
    VoidCallback? onKeyDown,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.space) {
          onPressed();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft && onKeyLeft != null) {
          onKeyLeft();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight && onKeyRight != null) {
          onKeyRight();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp && onKeyUp != null) {
          onKeyUp();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && onKeyDown != null) {
          onKeyDown();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          final scheme = Theme.of(context).colorScheme;

          Color bg;
          Color fg;

          if (customBg != null) {
            bg = isFocused
                ? customBg.withValues(alpha: 0.9)
                : customBg.withValues(alpha: 0.7);
            fg = customFg ?? Colors.white;
          } else if (isPrimary) {
            bg = isFocused ? scheme.primary : scheme.primaryContainer;
            fg = isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;
          } else {
            bg = isFocused
                ? scheme.surfaceContainerHighest
                : scheme.surfaceContainerHigh;
            fg = isFocused ? scheme.onSurface : scheme.onSurfaceVariant;
          }

          return InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedScale(
              scale: isFocused ? 1.04 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: (customBg ?? scheme.primary)
                                .withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        style: MoaiText.body(
                          context,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: fg,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
