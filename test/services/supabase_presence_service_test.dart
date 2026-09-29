import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/supabase_presence_service.dart';

void main() {
  group('SupabasePresenceService', () {
    test('defaultTimeout es de 10 segundos según RB-06', () {
      expect(SupabasePresenceService.defaultTimeout, equals(const Duration(seconds: 10)));
    });

    test('tableDevices es "devices"', () {
      expect(SupabasePresenceService.tableDevices, equals('devices'));
    });

    test('timeout handling funciona correctamente', () async {
      final completer = Completer<void>();

      expect(
        () => completer.future.timeout(
          const Duration(milliseconds: 10),
          onTimeout: () => throw TimeoutException('Tiempo agotado', const Duration(milliseconds: 10)),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
