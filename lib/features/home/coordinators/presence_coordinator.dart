import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:moai3/models/device_record.dart';
import 'package:moai3/services/supabase_presence_service.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';

/// Único dueño de la presencia del dispositivo (SPEC-22 / SPEC-50 §2.4).
///
/// - Online con heartbeat en TV y Arcade; offline en el resto de las secciones.
/// - El canal actual se reporta solo mientras la sección es TV.
/// - Escucha el registro del dispositivo y avisa si lo bloquean en vivo.
class PresenceCoordinator {
  PresenceCoordinator({
    required this.deviceId,
    required this.presence,
    required this.channels,
    required this.watchParty,
    required this.onBlocked,
    this.heartbeatInterval = const Duration(seconds: 60),
  }) {
    channels.addListener(_reportChannelIfWatching);
    watchParty.addListener(_onWatchPartyChanged);
    _watchPartyEnabled = watchParty.enabled;
    _watchBlock();
  }

  final String deviceId;
  final SupabasePresenceService presence;
  final ChannelProvider channels;
  final WatchPartyProvider watchParty;

  /// Se llama una vez si el administrador desactiva el dispositivo.
  final void Function(String? reason) onBlocked;
  final Duration heartbeatInterval;

  PresenceMode _mode = PresenceMode.offline;
  bool _watchPartyEnabled = false;
  bool _blocked = false;
  Timer? _heartbeat;
  StreamSubscription<DeviceRecord>? _deviceSub;

  void setMode(PresenceMode mode) {
    _mode = mode;
    _heartbeat?.cancel();
    _heartbeat = null;

    if (mode == PresenceMode.offline) {
      unawaited(presence.updateOnlineStatus(deviceId: deviceId, online: false));
      watchParty.reportCurrentChannel();
      return;
    }

    unawaited(presence.updateOnlineStatus(deviceId: deviceId, online: true));
    if (mode == PresenceMode.watching) {
      watchParty.reportPlayingChannel(channels.selectedChannel);
    } else {
      watchParty.reportCurrentChannel();
    }
    _heartbeat = Timer.periodic(heartbeatInterval, (_) {
      unawaited(presence.sendHeartbeat(deviceId: deviceId));
    });
  }

  void _reportChannelIfWatching() {
    if (_mode != PresenceMode.watching) return;
    watchParty.reportPlayingChannel(channels.selectedChannel);
  }

  void _onWatchPartyChanged() {
    if (watchParty.enabled == _watchPartyEnabled) return;
    _watchPartyEnabled = watchParty.enabled;
    if (_watchPartyEnabled) _reportChannelIfWatching();
  }

  void _watchBlock() {
    try {
      _deviceSub = presence.watchDevice(deviceId).listen(
        (record) {
          if (_blocked || record.isActive) return;
          _blocked = true;
          onBlocked(record.blockReason);
        },
        onError: (Object e) =>
            debugPrint('[PresenceCoordinator] watchDevice: $e'),
      );
    } catch (e) {
      // Sin Supabase inicializado (tests, sin red al arrancar): sin bloqueo en vivo.
      debugPrint('[PresenceCoordinator] Bloqueo en vivo no disponible: $e');
    }
  }

  void dispose() {
    _heartbeat?.cancel();
    unawaited(_deviceSub?.cancel());
    channels.removeListener(_reportChannelIfWatching);
    watchParty.removeListener(_onWatchPartyChanged);
  }
}

/// Qué presencia corresponde a la sección visible.
enum PresenceMode {
  /// TV: online y reportando el canal que se mira.
  watching,

  /// Arcade: online (para recibir invitaciones) sin canal.
  available,

  /// Agenda, Ajustes, etc.: offline.
  offline,
}
