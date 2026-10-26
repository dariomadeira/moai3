import 'dart:async';

import 'package:moai3/engine/moai_engine_player.dart';
import 'package:moai3/services/titan_ranger_service.dart';

/// Lo que el reproductor le cuenta a Titan Ranger mientras se ve una
/// película, como la app oficial.
///
/// El video viene del proxy local de Ranger, que lo va bajando: hay que
/// avisarle qué hace el reproductor para que baje lo que corresponde, sobre
/// todo al saltar, y detenerlo al salir. Con un stream que no es del proxy
/// ([active] en falso) no hace nada.
class TitanPlaybackBridge {
  TitanPlaybackBridge({required String streamUrl, required this.programName})
    : active = _isLocalProxy(streamUrl);

  /// El programa en Ranger: el que se le pasó a `PrepareProgram` (el ID de
  /// la película).
  final String programName;

  /// El stream viene del proxy local de Ranger.
  final bool active;

  bool _prepared = false;
  bool _seeking = false;
  bool _sawBuffering = false;
  bool _ended = false;
  bool _failed = false;

  static bool _isLocalProxy(String url) {
    final host = Uri.tryParse(url)?.host;
    return host == '127.0.0.1' || host == 'localhost';
  }

  /// Cada evento del motor: arranque, fin de un salto, final y error.
  void onEngineEvent(MoaiEngineEvent event) {
    if (!active) return;
    final state = event.state;
    if (!_prepared &&
        (event.firstFrameRendered || state == MoaiEngineState.ready)) {
      _prepared = true;
      unawaited(TitanRangerService.playerEvent('onPrepared'));
      unawaited(TitanRangerService.playerOperation('start'));
    }
    // Salto completo: el motor cargó el destino y volvió a estar listo.
    if (_seeking && state == MoaiEngineState.buffering) {
      _sawBuffering = true;
    }
    if (_seeking && _sawBuffering && state == MoaiEngineState.ready) {
      _seeking = false;
      unawaited(TitanRangerService.playerEvent('onSeekComplete'));
    }
    if (state == MoaiEngineState.ended && !_ended) {
      _ended = true;
      unawaited(TitanRangerService.playerEvent('onCompletion'));
    }
    if (state == MoaiEngineState.error && !_failed) {
      _failed = true;
      unawaited(
        TitanRangerService.playerEvent('onError', extra: event.errorCode ?? 0),
      );
    }
  }

  /// Por dónde va y cuánto hay cargado por delante, para que baje lo que
  /// viene.
  void onPosition(Duration position, Duration buffered) {
    if (!active || !_prepared) return;
    unawaited(
      TitanRangerService.playBuffer(
        progress: position,
        buffer: buffered > position ? buffered - position : Duration.zero,
      ),
    );
  }

  void onPause() {
    if (active) unawaited(TitanRangerService.playerOperation('pause'));
  }

  void onResume() {
    if (active) unawaited(TitanRangerService.playerOperation('start'));
  }

  /// Antes de saltar en el reproductor: Ranger salta primero y empieza a
  /// bajar desde [target] (antes, ese tramo da 404). Termina cuando Ranger
  /// respondió.
  Future<void> beforeSeek(Duration target) async {
    if (!active) return;
    await TitanRangerService.seek(name: programName, moment: target);
    await TitanRangerService.playerOperation('seekTo');
    _seeking = true;
    _sawBuffering = false;
  }

  /// Se vuelve a cargar el video (reintento): como un arranque nuevo.
  void reset() {
    _prepared = false;
    _failed = false;
    _seeking = false;
  }

  /// Se cerró el reproductor: avisa "end" y detiene el programa (si no,
  /// Ranger sigue bajando la película en segundo plano).
  void close() {
    if (active) unawaited(TitanRangerService.endProgram(name: programName));
  }
}
