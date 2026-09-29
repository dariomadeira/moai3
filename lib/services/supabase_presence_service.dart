import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moai3/models/device_record.dart';

/// Resultado del flujo de verificación inicial de presencia.
class DeviceVerificationResult {
  final DeviceRecord record;
  final bool isNewRegistration;

  const DeviceVerificationResult({
    required this.record,
    required this.isNewRegistration,
  });
}

/// Servicio de presencia y verificación de dispositivos contra Supabase.
/// Implementa los flujos 3.1, 3.2 y las reglas RB-02, RB-03, RB-04, RB-06, RB-10 de SPEC-22.
class SupabasePresenceService {
  static const String tableDevices = 'devices';
  static const Duration defaultTimeout = Duration(seconds: 10);

  final SupabaseClient? client;

  SupabasePresenceService({this.client});

  SupabaseClient get _effectiveClient => client ?? Supabase.instance.client;

  /// Verifica el dispositivo en Supabase (Cold Start - Flujo 3.1).
  /// Si existe -> actualiza app_version, last_seen y online = true.
  /// Si no existe -> registra el dispositivo con is_active = true y online = true.
  ///
  /// Lanza [TimeoutException] si no se recibe respuesta antes de [timeout].
  Future<DeviceVerificationResult> verifyAndRegisterDevice({
    required String deviceId,
    required String appVersion,
    Duration timeout = defaultTimeout,
  }) async {
    return _executeVerification(
      deviceId: deviceId,
      appVersion: appVersion,
    ).timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'Tiempo de espera agotado al conectar con Supabase (10s)',
        timeout,
      ),
    );
  }

  Future<DeviceVerificationResult> _executeVerification({
    required String deviceId,
    required String appVersion,
  }) async {
    final client = _effectiveClient;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 1. Consultar si el registro existe
    final response = await client
        .from(tableDevices)
        .select()
        .eq('device_id', deviceId)
        .maybeSingle();

    if (response != null) {
      // Registro existente: actualizar last_seen, app_version y online = true
      final updateData = {
        'app_version': appVersion,
        'online': true,
        'last_seen': nowIso,
        'updated_at': nowIso,
      };

      final updatedResponse = await client
          .from(tableDevices)
          .update(updateData)
          .eq('device_id', deviceId)
          .select()
          .single();

      final record = DeviceRecord.fromJson(updatedResponse);
      return DeviceVerificationResult(
        record: record,
        isNewRegistration: false,
      );
    } else {
      // No existe: crear nuevo registro (is_active = true, online = true)
      final insertData = {
        'device_id': deviceId,
        'app_version': appVersion,
        'is_active': true,
        'online': true,
        'last_seen': nowIso,
        'first_seen': nowIso,
        'created_at': nowIso,
        'updated_at': nowIso,
      };

      final insertedResponse = await client
          .from(tableDevices)
          .insert(insertData)
          .select()
          .single();

      final record = DeviceRecord.fromJson(insertedResponse);
      return DeviceVerificationResult(
        record: record,
        isNewRegistration: true,
      );
    }
  }

  /// Actualiza el estado online/offline del dispositivo (Flujo 3.2 y CASO-UC-04/06).
  Future<void> updateOnlineStatus({
    required String deviceId,
    required bool online,
  }) async {
    try {
      final client = _effectiveClient;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final data = <String, dynamic>{
        'online': online,
        'updated_at': nowIso,
      };
      if (online) {
        data['last_seen'] = nowIso;
      }

      await client
          .from(tableDevices)
          .update(data)
          .eq('device_id', deviceId);
    } catch (_) {
      // Silenciar o registrar error en operaciones de background al cerrar la app
    }
  }

  /// Envía un latido (heartbeat) periódico para mantener el estado online y last_seen actualizado
  /// mientras la app permanezca en primer plano (SPEC-22).
  Future<void> sendHeartbeat({
    required String deviceId,
  }) async {
    try {
      final client = _effectiveClient;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await client
          .from(tableDevices)
          .update({
            'online': true,
            'last_seen': nowIso,
            'updated_at': nowIso,
          })
          .eq('device_id', deviceId);
    } catch (_) {
      // Silenciar errores transitorios de red durante latidos periódicos de fondo
    }
  }

  /// Stream para escuchar en tiempo real cambios del registro del dispositivo
  /// (por ejemplo, si el administrador bloquea el dispositivo en vivo).
  Stream<DeviceRecord> watchDevice(String deviceId) {
    final client = _effectiveClient;
    return client
        .from(tableDevices)
        .stream(primaryKey: ['device_id'])
        .eq('device_id', deviceId)
        .map((list) => list.isNotEmpty ? DeviceRecord.fromJson(list.first) : throw Exception('Dispositivo no encontrado'));
  }
}
