import 'dart:async';
import 'dart:math' as math;
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/services/voice_audio_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/theme/moai_icons.dart';

part 'tv_voice_test/tv_voice_test_views.dart';

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
      duration: const Duration(milliseconds: 1400),
    );

    VoiceAudioService.initialize();
    VoiceAudioService.addPlaybackListener(_onPlaybackComplete);
    _initDiagnostic();
  }

  void _onPlaybackComplete() {
    if (!mounted) return;
    _waveController.stop();
    setState(() => _isPlaying = false);
  }

  @override
  void dispose() {
    VoiceAudioService.removePlaybackListener(_onPlaybackComplete);
    _waveController.dispose();
    _recordTimer?.cancel();
    VoiceAudioService.stopPlayback();
    _recordFocus.dispose();
    _playFocus.dispose();
    _rerecordFocus.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  Future<void> _initDiagnostic() async {
    setState(() => _isLoading = true);
    final hasPerm = await VoiceAudioService.hasPermission();
    final hw = await VoiceAudioService.checkHardware();

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
    await VoiceAudioService.requestPermission();
    await Future.delayed(const Duration(milliseconds: 600));
    final hasPerm = await VoiceAudioService.hasPermission();
    if (!mounted) return;
    setState(() => _hasPermission = hasPerm);
  }

  Future<void> _startRecording() async {
    if (_isPlaying) {
      await VoiceAudioService.stopPlayback();
      _isPlaying = false;
    }

    if (!_hasPermission) {
      await _requestPermission();
      if (!_hasPermission) {
        setState(() {
          _errorMessage = LocaleKeys.mic_test_perm_denied.tr();
        });
        return;
      }
    }

    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
      _errorMessage = null;
    });
    _waveController.repeat();

    final res = await VoiceAudioService.startRecording();
    if (res['success'] != true) {
      if (!mounted) return;
      _waveController.stop();
      setState(() {
        _isRecording = false;
        _errorMessage = LocaleKeys.mic_test_err_start.tr(
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

    final res = await VoiceAudioService.stopRecording();
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
        _errorMessage = LocaleKeys.mic_test_err_stop.tr(
          namedArgs: {'error': '${res['error'] ?? ''}'},
        );
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await VoiceAudioService.stopPlayback();
      _waveController.stop();
      setState(() => _isPlaying = false);
    } else {
      setState(() {
        _isPlaying = true;
        _errorMessage = null;
      });
      _waveController.repeat();
      final res = await VoiceAudioService.playRecording();
      if (!mounted) return;
      if (res['success'] != true) {
        _waveController.stop();
        setState(() {
          _isPlaying = false;
          _errorMessage = LocaleKeys.mic_test_err_play.tr(
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
      icon: MoaiIcons.micSettings,
      iconColor: _isRecording ? scheme.error : scheme.primary,
      title: LocaleKeys.mic_test_title.tr(),
      subtitle: LocaleKeys.mic_test_subtitle.tr(),
      content: _isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Escenario: orbe, onda, progreso y controles.
                _buildMainCard(scheme),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildError(scheme),
                ],
                const SizedBox(height: 14),
                // Consejo de uso y entrada de audio detectada.
                _buildInfoFooter(scheme),
              ],
            ),
      actions: [
        TvDialogButton(
          focusNode: _closeFocus,
          label: LocaleKeys.common_close.tr(),
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
}
