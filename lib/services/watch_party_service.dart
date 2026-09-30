import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moai3/models/friend_info.dart';

/// Excepción de negocio para operaciones de Miremos Juntos (Watch Party).
class WatchPartyException implements Exception {
  final String message;
  const WatchPartyException(this.message);

  @override
  String toString() => message;
}

/// Servicio encargado de la gestión de amistades y presencia en tiempo real (SPEC-36).
class WatchPartyService {
  static const String tableFriends = 'device_friends';
  static const String tableDevices = 'devices';

  final SupabaseClient? client;

  WatchPartyService({this.client});

  SupabaseClient get _effectiveClient => client ?? Supabase.instance.client;

  /// Obtiene el user_code asignado a este dispositivo directamente desde Supabase.
  Future<String?> getDeviceUserCode(String deviceId) async {
    try {
      final client = _effectiveClient;
      final row = await client
          .from(tableDevices)
          .select('user_code')
          .eq('device_id', deviceId)
          .maybeSingle();
      return row?['user_code'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Obtiene el nickname actual asignado al dispositivo desde Supabase.
  Future<String?> getDeviceNickname(String deviceId) async {
    try {
      final client = _effectiveClient;
      final row = await client
          .from(tableDevices)
          .select('nickname')
          .eq('device_id', deviceId)
          .maybeSingle();
      return row?['nickname'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Actualiza el nickname del dispositivo en Supabase.
  Future<void> updateNickname({
    required String deviceId,
    required String nickname,
  }) async {
    try {
      final client = _effectiveClient;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await client
          .from(tableDevices)
          .update({
            'nickname': nickname.trim(),
            'updated_at': nowIso,
          })
          .eq('device_id', deviceId);
    } catch (e) {
      throw const WatchPartyException('nickname_save_error');
    }
  }

  /// Obtiene la lista de amigos con su estado de presencia actual.
  Future<List<FriendInfo>> getFriends(String deviceId) async {
    try {
      final client = _effectiveClient;

      // 1. Obtener los IDs de dispositivos amigos
      final friendsRows = await client
          .from(tableFriends)
          .select('friend_device_id')
          .eq('device_id', deviceId);

      final friendIds = (friendsRows as List)
          .map((row) => row['friend_device_id'] as String)
          .toList();

      if (friendIds.isEmpty) {
        return [];
      }

      // 2. Consultar el estado y metadatos de los amigos en 'devices'
      final devicesRows = await client
          .from(tableDevices)
          .select('device_id, user_code, nickname, online, last_seen')
          .inFilter('device_id', friendIds);

      final friendsList = (devicesRows as List)
          .map((row) => FriendInfo.fromDeviceJson(row as Map<String, dynamic>))
          .toList();

      // Ordenar: primero los que están online, luego por nombre/código
      friendsList.sort((a, b) {
        if (a.isOnline != b.isOnline) {
          return a.isOnline ? -1 : 1;
        }
        final nameA = a.nickname ?? a.userCode;
        final nameB = b.nickname ?? b.userCode;
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });

      return friendsList;
    } catch (e) {
      if (e is WatchPartyException) rethrow;
      throw const WatchPartyException('friends_load_error');
    }
  }

  /// Agrega un amigo por su código de usuario `MOAI-XXXX` (Reglas RB-05, RB-07, RB-08).
  Future<FriendInfo> addFriend({
    required String deviceId,
    required String myUserCode,
    required String friendUserCodeInput,
  }) async {
    // Normalizar código ingresado: quitar espacios y pasar a mayúsculas
    var normalizedCode = friendUserCodeInput.trim().toUpperCase();
    if (!normalizedCode.startsWith('MOAI-')) {
      normalizedCode = 'MOAI-$normalizedCode';
    }

    // RB-05: Un usuario no puede agregarse a sí mismo
    final myNormalizedCode = myUserCode.trim().toUpperCase();
    if (normalizedCode == myNormalizedCode) {
      throw const WatchPartyException('friend_add_error_self');
    }

    try {
      final client = _effectiveClient;

      // RB-07: Validar si el código existe en 'devices'
      final targetDevice = await client
          .from(tableDevices)
          .select('device_id, user_code, nickname, online, last_seen')
          .eq('user_code', normalizedCode)
          .maybeSingle();

      if (targetDevice == null) {
        throw const WatchPartyException('friend_add_error_not_found');
      }

      final friendDeviceId = targetDevice['device_id'] as String;

      // Doble verificación por si deviceId coincide aunque el código fuera alterado
      if (friendDeviceId == deviceId) {
        throw const WatchPartyException('friend_add_error_self');
      }

      // RB-08: Verificar si ya estaba agregado
      final existingFriendship = await client
          .from(tableFriends)
          .select('friend_device_id')
          .eq('device_id', deviceId)
          .eq('friend_device_id', friendDeviceId)
          .maybeSingle();

      if (existingFriendship != null) {
        throw const WatchPartyException('friend_add_error_already_added');
      }

      // Insertar en 'device_friends'
      await client.from(tableFriends).insert({
        'device_id': deviceId,
        'friend_device_id': friendDeviceId,
      });

      return FriendInfo.fromDeviceJson(targetDevice);
    } catch (e) {
      if (e is WatchPartyException) rethrow;
      throw const WatchPartyException('friend_add_error_generic');
    }
  }

  /// Elimina una relación de amistad (Regla RB-09).
  Future<void> removeFriend({
    required String deviceId,
    required String friendDeviceId,
  }) async {
    try {
      final client = _effectiveClient;
      await client
          .from(tableFriends)
          .delete()
          .eq('device_id', deviceId)
          .eq('friend_device_id', friendDeviceId);
    } catch (e) {
      throw const WatchPartyException('friends_delete_error');
    }
  }
}
