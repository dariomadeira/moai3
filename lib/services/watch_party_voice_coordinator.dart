import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:moai3/models/voice_message_record.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/remote_voice_test_service.dart';
import 'package:moai3/services/watch_party_service.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _QueuedVoiceMessage {
  final VoiceMessageRecord record;
  final String senderName;

  _QueuedVoiceMessage({required this.record, required this.senderName});
}

/// Coordinador de voz y cola de reproducción de Watch Party (SPEC-37).
/// Maneja Toggle-to-Talk, antiacople acústico, filtro de privacidad de amigos mutuos
/// y reproducción secuencial FIFO con LoudnessEnhancer.
class WatchPartyVoiceCoordinator extends ChangeNotifier {
  final WatchPartyProvider watchPartyProvider;
  final WatchPartyService watchPartyService;
  final DeviceIdentityService identityService;

  RealtimeChannel? _realtimeChannel;
  final List<_QueuedVoiceMessage> _incomingQueue = [];

  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  bool _isPlaying = false;
  String? _currentSpeakerName;
  int _currentAudioDurationMs = 0;
  Timer? _playbackTimeoutTimer;
  bool _isQueuePaused = false;

  WatchPartyVoiceCoordinator({
    required this.watchPartyProvider,
    required this.watchPartyService,
    required this.identityService,
  }) {
    _init();
  }

  bool get isRecording => _isRecording;
  int get recordingSeconds => _recordingSeconds;
  bool get isPlaying => _isPlaying;
  String? get currentSpeakerName => _currentSpeakerName;
  int get currentAudioDurationMs => _currentAudioDurationMs;
  int get queueLength => _incomingQueue.length;

  void _init() {
    RemoteVoiceTestService.initialize();
    RemoteVoiceTestService.addPlaybackListener(_onPlaybackComplete);

    // Suscribirse a mensajes de voz en Supabase Realtime si Watch Party está activo
    if (watchPartyProvider.enabled) {
      _subscribeToRealtime();
    }

    watchPartyProvider.addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    if (watchPartyProvider.enabled && _realtimeChannel == null) {
      _subscribeToRealtime();
    } else if (!watchPartyProvider.enabled && _realtimeChannel != null) {
      _unsubscribeFromRealtime();
      _incomingQueue.clear();
      _stopPlayback();
    }
  }

  void _subscribeToRealtime() {
    try {
      _realtimeChannel = watchPartyService.subscribeToVoiceMessages(
        onMessageReceived: handleIncomingVoiceMessage,
      );
    } catch (e) {
      debugPrint('[WatchPartyVoiceCoordinator] Error al suscribir a Realtime: $e');
    }
  }

  void _unsubscribeFromRealtime() {
    try {
      _realtimeChannel?.unsubscribe();
    } catch (e) {
      debugPrint('[WatchPartyVoiceCoordinator] Error al desuscribir de Realtime: $e');
    }
    _realtimeChannel = null;
  }

  /// Procesa un mensaje de voz entrante con el estricto filtro de privacidad (SPEC-37):
  /// 1. Ignora mensajes propios.
  /// 2. Ignora mensajes si no coinciden con el canal actual.
  /// 3. Ignora mensajes si el emisor NO es un amigo en la lista local de este televisor.
  @visibleForTesting
  void handleIncomingVoiceMessage(VoiceMessageRecord message) {
    if (!watchPartyProvider.enabled) return;

    final myDeviceId = identityService.getOrCreateDeviceId();
    if (message.senderDeviceId == myDeviceId) {
      return; // Mensaje propio
    }

    // 1. Filtro de canal sintonizado
    final currentChId = watchPartyProvider.currentChannelId;
    if (currentChId == null || currentChId.isEmpty) {
      return; // No hay canal sintonizado
    }

    final isSameChannel = message.channelId == currentChId ||
        (watchPartyProvider.currentChannelName != null &&
            message.channelName != null &&
            _isSameNormalizedChannel(
              watchPartyProvider.currentChannelName!,
              message.channelName!,
            ));

    if (!isSameChannel) {
      return; // Está en otro canal
    }

    // 2. Filtro estricto de privacidad / confianza (Solo amigos agregados)
    final friends = watchPartyProvider.friends;
    final friend = friends.cast<dynamic>().firstWhere(
          (f) => f.deviceId == message.senderDeviceId,
          orElse: () => null,
        );

    if (friend == null) {
      // Regla de privacidad: El emisor no está en mi lista de amigos -> NUNCA reproducir
      return;
    }

    final senderName = friend.nickname ?? friend.userCode;

    // 3. Encolar en cola FIFO
    _incomingQueue.add(_QueuedVoiceMessage(
      record: message,
      senderName: senderName,
    ));

    _playNextIfPossible();
  }

  bool _isSameNormalizedChannel(String a, String b) {
    String clean(String s) => s
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\b(hd|fhd|sd|4k|argentina|arg)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return clean(a).isNotEmpty && clean(a) == clean(b);
  }

  /// Alterna entre comenzar y terminar la grabación (Toggle-to-Talk) (SPEC-37).
  Future<void> toggleRecording() async {
    if (_isRecording) {
      await stopAndSendRecording();
    } else {
      await startRecording();
    }
  }

  /// Inicia la grabación del micrófono y aplica antiacople acústico estricto.
  Future<void> startRecording() async {
    if (_isRecording) return;

    // Verificar / solicitar permisos si hace falta
    final hasPerm = await RemoteVoiceTestService.hasPermission();
    if (!hasPerm) {
      await RemoteVoiceTestService.requestPermission();
      final granted = await RemoteVoiceTestService.hasPermission();
      if (!granted) return;
    }

    // Antiacople: Pausar y cortar inmediatamente cualquier audio de fondo
    _isQueuePaused = true;
    _stopPlayback();

    final res = await RemoteVoiceTestService.startRecording();
    if (res['success'] == true) {
      _isRecording = true;
      _recordingSeconds = 0;
      notifyListeners();

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _recordingSeconds++;
        notifyListeners();
        // Límite de seguridad: máximo 30 segundos por nota de voz
        if (_recordingSeconds >= 30) {
          stopAndSendRecording();
        }
      });
    }
  }

  /// Detiene la grabación, sube el audio .m4a y lo transmite a los amigos del canal.
  Future<void> stopAndSendRecording() async {
    if (!_isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;
    _isRecording = false;
    final recordedDurationMs = _recordingSeconds * 1000;
    _recordingSeconds = 0;
    notifyListeners();

    try {
      final res = await RemoteVoiceTestService.stopRecording();
      if (res['success'] == true && res['path'] != null) {
        final filePath = res['path'] as String;
        final file = File(filePath);

        if (await file.exists() && (await file.length()) > 0) {
          final bytes = await file.readAsBytes();
          final myDeviceId = identityService.getOrCreateDeviceId();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'voice_${myDeviceId}_$timestamp.m4a';

          // 1. Subir a Supabase Storage
          final audioUrl = await watchPartyService.uploadVoiceAudio(
            deviceId: myDeviceId,
            bytes: bytes,
            fileName: fileName,
          );

          // 2. Enviar evento a la tabla voice_messages
          final currentChId = watchPartyProvider.currentChannelId ?? '';
          final currentChName = watchPartyProvider.currentChannelName;

          if (currentChId.isNotEmpty) {
            await watchPartyService.sendVoiceMessage(
              senderDeviceId: myDeviceId,
              channelId: currentChId,
              channelName: currentChName,
              audioUrl: audioUrl,
              durationMs: recordedDurationMs > 0 ? recordedDurationMs : 2000,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[WatchPartyVoiceCoordinator] Error al finalizar y enviar grabación: $e');
    } finally {
      // Reanudar cola de reproducción
      _isQueuePaused = false;
      _playNextIfPossible();
    }
  }

  /// Cancela la grabación actual sin enviarla.
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _isRecording = false;
    _recordingSeconds = 0;
    notifyListeners();

    try {
      await RemoteVoiceTestService.stopRecording();
    } catch (e) {
      debugPrint('[WatchPartyVoiceCoordinator] Error al cancelar grabación: $e');
    }

    _isQueuePaused = false;
    _playNextIfPossible();
  }

  void _playNextIfPossible() {
    if (_incomingQueue.isEmpty || _isPlaying || _isRecording || _isQueuePaused) {
      return;
    }

    final item = _incomingQueue.removeAt(0);
    _isPlaying = true;
    _currentSpeakerName = item.senderName;
    _currentAudioDurationMs = item.record.durationMs;
    notifyListeners();

    // Reproducir con el motor nativo + LoudnessEnhancer
    RemoteVoiceTestService.playAudio(item.record.audioUrl);

    // Timeout de seguridad en caso de que el callback no se dispare
    _playbackTimeoutTimer?.cancel();
    final safetySeconds = (item.record.durationMs / 1000).ceil() + 3;
    _playbackTimeoutTimer = Timer(Duration(seconds: safetySeconds.clamp(4, 25)), () {
      _onPlaybackComplete();
    });
  }

  void _onPlaybackComplete() {
    if (!_isPlaying) return;
    _playbackTimeoutTimer?.cancel();
    _playbackTimeoutTimer = null;
    _isPlaying = false;
    _currentSpeakerName = null;
    _currentAudioDurationMs = 0;
    notifyListeners();

    _playNextIfPossible();
  }

  void _stopPlayback() {
    _playbackTimeoutTimer?.cancel();
    _playbackTimeoutTimer = null;
    _isPlaying = false;
    _currentSpeakerName = null;
    _currentAudioDurationMs = 0;
    try {
      RemoteVoiceTestService.stopPlayback();
    } catch (_) {}
    notifyListeners();
  }

  /// Pausa temporal de la cola (por ejemplo, al abrir un diálogo o menú modal).
  void pauseQueue() {
    _isQueuePaused = true;
    _stopPlayback();
  }

  /// Reanuda la cola al cerrar el diálogo.
  void resumeQueue() {
    _isQueuePaused = false;
    _playNextIfPossible();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _playbackTimeoutTimer?.cancel();
    RemoteVoiceTestService.removePlaybackListener(_onPlaybackComplete);
    _unsubscribeFromRealtime();
    watchPartyProvider.removeListener(_onProviderChanged);
    super.dispose();
  }
}
