import 'package:flutter/services.dart';

/// Canales nativos de moai3 (SPEC-11). Única fuente de los nombres: el lado
/// Kotlin los registra en `MainActivity`, `PluginLoader`, `ArcadeEmulatorManager`,
/// `RemoteVoiceManager` y `TitanRangerManager`.
abstract final class PlatformChannels {
  /// RAM, identidad de hardware, emulador, salir, sonidos D-pad, instalar APK.
  static const device = MethodChannel('com.infomak.moai.tv/device');

  /// Motor de video ExoPlayer (create/setMedia/play/pauseAll/resumeAll…).
  static const player = MethodChannel('com.infomak.moai.tv/player');

  /// Eventos de una instancia del motor de video.
  static EventChannel playerEvents(int handle) =>
      EventChannel('com.infomak.moai.tv/player/events/$handle');

  /// Carga y ejecución de plugins `.dex`.
  static const plugin = MethodChannel('com.infomak.moai.tv/plugin');

  /// Emulador FBNeo, ROMs y gamepads.
  static const arcade = MethodChannel('com.infomak.moai/arcade_channel');

  /// Micrófono del control remoto y reproducción de mensajes de voz.
  static const remoteVoice = MethodChannel('com.infomak.moai.tv/remote_voice');

  /// Permiso de VPN del sistema (catálogo de películas).
  static const vpnPermission =
      MethodChannel('com.infomak.moai.tv/vpn_permission');

  /// Reproducción VOD (películas).
  static const titanRanger = MethodChannel('com.infomak.moai.tv/titan_ranger');
}
