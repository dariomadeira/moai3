import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';

/// Estados posibles de una sesión de Arcade Netplay a la distancia.
enum ArcadeNetplayStatus {
  /// Sin sesión activa. Modo local normal.
  idle,

  /// El Host envió una invitación y espera respuesta (timeout 30s).
  inviting,

  /// El Invitado recibió una invitación y puede Aceptar o Rechazar.
  invited,

  /// Ambos acordaron jugar. Se verifica y descarga la ROM si es necesario.
  preparingRoms,

  /// Ambas consolas tienen la ROM lista y verificada.
  ready,

  /// Partida activa en tiempo real.
  inGame,

  /// Pérdida temporal de paquetes o micro-corte de red.
  reconnecting,

  /// Sesión cancelada, rechazada o terminada.
  terminated,
}

/// Datos de una invitación entrante de Arcade.
@immutable
class ArcadeNetplayInvite {
  final String sessionId;
  final String hostDeviceId;
  final String hostNickname;
  final String guestDeviceId;
  final String romFilename;
  final String romName;
  final String romUrl;

  const ArcadeNetplayInvite({
    required this.sessionId,
    required this.hostDeviceId,
    required this.hostNickname,
    required this.guestDeviceId,
    required this.romFilename,
    required this.romName,
    required this.romUrl,
  });

  factory ArcadeNetplayInvite.fromMap(Map<String, dynamic> map) {
    return ArcadeNetplayInvite(
      sessionId: map['sessionId'] as String? ?? '',
      hostDeviceId: map['hostDeviceId'] as String? ?? '',
      hostNickname: map['hostNickname'] as String? ?? LocaleKeys.common_friend.tr(),
      guestDeviceId: map['guestDeviceId'] as String? ?? '',
      romFilename: map['romFilename'] as String? ?? '',
      romName: map['romName'] as String? ?? '',
      romUrl: map['romUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'hostDeviceId': hostDeviceId,
      'hostNickname': hostNickname,
      'guestDeviceId': guestDeviceId,
      'romFilename': romFilename,
      'romName': romName,
      'romUrl': romUrl,
    };
  }
}

/// Representa el estado reactivo completo de una sesión compartida de Arcade.
class ArcadeNetplaySession {
  final String sessionId;
  final bool isHost;
  final String myDeviceId;
  final String myNickname;
  final String peerDeviceId;
  final String peerNickname;
  final String romFilename;
  final String romName;
  final String romUrl;

  ArcadeNetplayStatus status;
  double myProgress;
  double peerProgress;
  String myStatusText;
  String peerStatusText;
  String? exitReason;

  ArcadeNetplaySession({
    required this.sessionId,
    required this.isHost,
    required this.myDeviceId,
    required this.myNickname,
    required this.peerDeviceId,
    required this.peerNickname,
    required this.romFilename,
    required this.romName,
    required this.romUrl,
    this.status = ArcadeNetplayStatus.preparingRoms,
    this.myProgress = 0.0,
    this.peerProgress = 0.0,
    String? myStatusText,
    String? peerStatusText,
    this.exitReason,
  })  : myStatusText = myStatusText ?? LocaleKeys.arcade_status_verifying.tr(),
        peerStatusText = peerStatusText ?? LocaleKeys.arcade_status_waiting.tr();

}
