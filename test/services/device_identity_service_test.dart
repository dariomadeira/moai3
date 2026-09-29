import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/device_record.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceRecord Model', () {
    test('serializa y deserializa correctamente desde JSON', () {
      final json = {
        'device_id': 'test-uuid-1234',
        'user_code': 'MOAI-AB12',
        'nickname': 'Dario TV',
        'app_version': '3.0.16',
        'is_active': true,
        'block_reason': null,
        'online': true,
        'last_seen': '2026-09-29T10:00:00.000Z',
        'first_seen': '2026-09-01T10:00:00.000Z',
        'created_at': '2026-09-01T10:00:00.000Z',
        'updated_at': '2026-09-29T10:00:00.000Z',
      };

      final record = DeviceRecord.fromJson(json);

      expect(record.deviceId, 'test-uuid-1234');
      expect(record.userCode, 'MOAI-AB12');
      expect(record.nickname, 'Dario TV');
      expect(record.appVersion, '3.0.16');
      expect(record.isActive, isTrue);
      expect(record.blockReason, isNull);
      expect(record.online, isTrue);

      final toJson = record.toJson();
      expect(toJson['device_id'], 'test-uuid-1234');
      expect(toJson['user_code'], 'MOAI-AB12');
      expect(toJson['nickname'], 'Dario TV');
      expect(toJson['is_active'], isTrue);
      expect(toJson['online'], isTrue);
    });

    test('maneja valores por defecto para campos faltantes', () {
      final json = {
        'device_id': 'uuid-only',
        'first_seen': '2026-09-01T10:00:00.000Z',
        'created_at': '2026-09-01T10:00:00.000Z',
        'updated_at': '2026-09-01T10:00:00.000Z',
      };

      final record = DeviceRecord.fromJson(json);

      expect(record.deviceId, 'uuid-only');
      expect(record.userCode, isNull);
      expect(record.appVersion, 'unknown');
      expect(record.isActive, isTrue);
      expect(record.online, isFalse);
      expect(record.lastSeen, isNull);
    });
  });

  group('DeviceIdentityService', () {
    late AppPreferences appPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      appPreferences = await AppPreferences.init();
    });

    test('genera un nuevo UUID v4 si no existe en SharedPreferences y lo persiste', () {
      final service = DeviceIdentityService(appPreferences);

      final deviceId1 = service.getOrCreateDeviceId();
      expect(deviceId1.isNotEmpty, isTrue);

      // Segunda llamada debe retornar exactamente el mismo ID persistido (RB-01)
      final deviceId2 = service.getOrCreateDeviceId();
      expect(deviceId2, equals(deviceId1));
    });

    test('reutiliza device_id preexistente si ya estaba guardado', () async {
      SharedPreferences.setMockInitialValues({
        DeviceIdentityService.keyDeviceId: 'pre-existing-device-id',
      });
      final prefs = await AppPreferences.init();
      final service = DeviceIdentityService(prefs);

      final deviceId = service.getOrCreateDeviceId();
      expect(deviceId, equals('pre-existing-device-id'));
    });
  });
}
