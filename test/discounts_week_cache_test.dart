import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moai3/models/discount_models.dart';
import 'package:moai3/services/discounts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late final service = DiscountsService.instance;
  final today = DateTime(2026, 11, 9);
  const coto = Discount(
    id: '1',
    merchant: 'Coto',
    benefit: '20%',
    percent: 20,
    bankIds: {'a'},
  );
  const dia = Discount(
    id: '2',
    merchant: 'Día',
    benefit: '10%',
    percent: 10,
    bankIds: {'b'},
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service.resetForTest();
    service.debugSetDiscounts(const [coto, dia]);
  });
  tearDown(() => service.resetForTest());

  test('la semana se reutiliza mientras nada cambia', () {
    final first = service.week(today);
    expect(identical(service.week(today), first), isTrue);
    expect(identical(service.merchants, service.merchants), isTrue);
  });

  test('otro día u otro rubro no reutilizan la semana', () {
    final first = service.week(today);
    expect(
      identical(service.week(today.add(const Duration(days: 1))), first),
      isFalse,
    );
    expect(
      identical(service.week(today, rubro: DiscountRubro.farmacias), first),
      isFalse,
    );
  });

  test('cada cambio de filtros se ve en la semana', () async {
    expect(service.week(today).first.discounts, isEmpty);

    await service.toggleBank('a');
    expect(service.week(today).first.discounts, [coto]);

    await service.toggleBank('b');
    expect(service.week(today).first.discounts, [coto, dia]);

    await service.toggleMerchant(dia.merchantKey);
    expect(service.week(today).first.discounts, [dia]);

    await service.setOnlyMine(false);
    expect(service.week(today).first.discounts, [coto, dia]);

    await service.toggleRubro(DiscountRubro.supermercados);
    expect(service.week(today).first.discounts, isEmpty);
    expect(service.merchants, isEmpty);
  });

  test('promos nuevas reemplazan la semana guardada', () async {
    await service.toggleBank('a');
    expect(service.week(today).first.discounts, [coto]);
    service.debugSetDiscounts(const []);
    expect(service.week(today).first.discounts, isEmpty);
  });

  test('sin internet, volver a entrar no repite las consultas', () async {
    var calls = 0;
    final dir = await Directory.systemTemp.createTemp('discounts_cache');
    addTearDown(() => dir.delete(recursive: true));
    service.resetForTest(
      directory: dir,
      client: MockClient((_) async {
        calls++;
        return http.Response('', 500);
      }),
    );

    Future<void> idle() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      while (service.isLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    await service.ensureLoaded();
    await idle();
    final afterFirst = calls;
    expect(afterFirst, greaterThan(0));

    await service.ensureLoaded();
    await idle();
    expect(calls, afterFirst);

    await service.refresh(force: true);
    expect(calls, greaterThan(afterFirst));
  });
}
