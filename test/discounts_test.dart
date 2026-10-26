import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moai3/features/discounts/discount_format.dart';
import 'package:moai3/features/discounts/widgets/discount_dialogs.dart';
import 'package:moai3/features/home/widgets/home_discounts_card.dart';
import 'package:moai3/models/discount_models.dart';
import 'package:moai3/services/discounts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/spanish_translations.dart';

const nacion = '0330e59b-b6e3-43eb-9083-a88fcc61e845';
const galicia = '88d8705e-2dda-46f9-8411-bb4916af858e';

/// Una tarjeta como las de `/v2/filter` de MODO (recortada de una real).
Map<String, dynamic> modoCard({
  String id = 'c1',
  String merchant = 'Coto',
  String benefit = '10% de reintegro',
  num percent = 10,
  List<String> days = const ['tuesday'],
  List<String> banks = const [nacion],
  num cap = 7500,
  String start = '2026-10-01',
  String stop = '2026-10-31',
}) => {
  'card_id': id,
  'card': {
    'benefit': benefit,
    'validity_place': merchant,
    'cashback_cap': '$cap',
    'participating_bank': 'BNA',
  },
  'benefit': {
    'conditions': {
      'schedule': {
        'start_date': start,
        'stop_date': stop,
        'days_of_week': days,
      },
      'payment_flow': {
        'flows': ['instore'],
      },
      'payment_methods': {
        'methods': [
          {'type': 'credit_card', 'issuer': 'master'},
          {'type': 'debit_card', 'issuer': 'master'},
          {'type': 'credit_card', 'issuer': 'american_express'},
        ],
      },
    },
  },
  'offer': {
    'outcomes': {
      'cashback': {'amount': percent, 'amount_type': 'percent'},
      'financing': {
        'installments': [
          {'type': 'sin_interes', 'number': 3},
        ],
      },
    },
    'requirements': {
      'banks': {'list': banks},
    },
    'limits': {
      'period_cap': {'reset_by': 'month', 'amount_by_period': cap},
    },
  },
};

void main() {
  // Martes 27 de octubre de 2026.
  final tuesday = DateTime(2026, 10, 27);

  group('Discount (de la API de MODO)', () {
    test('lee comercio, porcentaje, tope, días, bancos y tarjetas', () {
      final d = Discount.fromModoCard(modoCard())!;
      expect(d.merchant, 'Coto');
      expect(d.percent, 10);
      expect(d.cap, 7500);
      expect(d.capPeriod, DiscountCapPeriod.month);
      expect(d.weekdays, {DateTime.tuesday});
      expect(d.bankIds, {nacion});
      expect(d.installments, 3);
      expect(d.cardBrands, ['American Express', 'Mastercard']);
      expect(d.instore, isTrue);
    });

    test('vale sólo los días y en la vigencia que dice', () {
      final d = Discount.fromModoCard(modoCard())!;
      expect(d.validOn(tuesday), isTrue);
      expect(d.validOn(DateTime(2026, 10, 28)), isFalse); // miércoles
      expect(d.validOn(DateTime(2026, 11, 3)), isFalse); // martes, vencida
    });

    test('una tarjeta rota se saltea sin romper', () {
      expect(Discount.fromModoCard({'card': 'x'}), isNull);
      expect(Discount.fromModoCard({}), isNull);
    });

    test('se guarda y se lee igual', () {
      final d = Discount.fromModoCard(modoCard())!;
      final back = Discount.fromJson(jsonDecode(jsonEncode(d.toJson())));
      expect(back.merchant, d.merchant);
      expect(back.weekdays, d.weekdays);
      expect(back.stop, d.stop);
      expect(back.bankIds, d.bankIds);
    });
  });

  group('la semana', () {
    final all = parseModoPages([
      jsonEncode({
        'cards': [
          modoCard(id: 'a'), // Coto 10%
          modoCard(id: 'b', percent: 25), // Coto
          modoCard(id: 'c', merchant: 'Día', percent: 20, banks: [galicia]),
          modoCard(id: 'd', merchant: 'Vea', percent: 15, banks: []),
          modoCard(id: 'a'), // repetida
        ],
      }),
    ]);

    test('sin bancos elegidos no muestra nada', () {
      expect(DiscountsService.bestPerMerchant(all, tuesday, {}), isEmpty);
    });

    test('el mejor primero, uno por comercio, sólo con mis bancos', () {
      final list = DiscountsService.bestPerMerchant(all, tuesday, {nacion});
      // Coto 25% (la mejor de Coto), Vea 15% (vale con cualquier banco);
      // Día no, es sólo con Galicia.
      expect(list.map((d) => '${d.merchant} ${d.percent}'), [
        'Coto 25.0',
        'Vea 15.0',
      ]);
    });

    test('las repetidas se descartan al leer', () {
      expect(all.length, 4);
    });
  });

  test('formatos', () {
    expect(DiscountFormat.money(12000), '\$12.000');
    expect(DiscountFormat.money(1500000), '\$1.500.000');
    expect(
      DiscountFormat.headline(Discount.fromModoCard(modoCard(percent: 20))!),
      '20%',
    );
  });

  group('DiscountsService', () {
    late Directory dir;
    var requests = <String>[];

    http.Client fakeApi() => MockClient((req) async {
      requests.add(req.url.path);
      if (req.url.path.endsWith('/banks')) {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode([
              {'id': nacion, 'name': 'Banco Nación', 'on_hub_list': 'true'},
              {'id': galicia, 'name': 'Galicia', 'on_hub_list': 'true'},
              {'id': 'x', 'name': 'Oculto', 'on_hub_list': 'false'},
            ]),
          ),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'cards': [modoCard()],
          'pagination': {'page': 1, 'total_pages': 1},
        }),
        200,
      );
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('descuentos');
      requests = [];
      DiscountsService.instance.resetForTest(client: fakeApi(), directory: dir);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('baja bancos y promos, y los guarda', () async {
      final service = DiscountsService.instance;
      await service.refresh(force: true);
      expect(service.banks.map((b) => b.name), ['Banco Nación', 'Galicia']);
      expect(File('${dir.path}/discounts.json').existsSync(), isTrue);

      // Mis bancos: Nación. El martes aparece Coto.
      await service.toggleBank(nacion);
      expect(service.discountsOn(tuesday).single.merchant, 'Coto');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('discount_bank_ids'), [nacion]);
    });

    test('ya bajado hoy, no vuelve a pedir', () async {
      final service = DiscountsService.instance;
      await service.refresh(force: true);
      final count = requests.length;
      await service.refresh();
      expect(requests.length, count);
    });
  });

  group('tarjeta del Inicio en el TV', () {
    Future<void> pumpCard(WidgetTester tester) async {
      useSpanishTranslations();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.reset());
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 810,
                height: 99,
                child: HomeDiscountsItem(
                  focusNode: focus,
                  onKeyLeft: () {},
                  onKeyUp: () {},
                  onKeyDown: () {},
                  now: () => DateTime(2026, 10, 26), // lunes
                ),
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      DiscountsService.instance.resetForTest(
        client: MockClient((_) async => http.Response('[]', 500)),
        directory: await Directory.systemTemp.createTemp('descuentos'),
      );
    });

    testWidgets('sin bancos pide elegirlos', (tester) async {
      await pumpCard(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(find.text('Elegí tus bancos y billeteras'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('con bancos: la semana entra y OK abre el día', (tester) async {
      final service = DiscountsService.instance;
      await tester.runAsync(() async {
        await service.ensureLoaded();
        await service.toggleBank(nacion);
      });
      service.debugSetDiscounts([Discount.fromModoCard(modoCard())!]);
      await pumpCard(tester);

      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Coto'), findsOneWidget); // el martes
      expect(tester.takeException(), isNull);

      // → al martes y OK: el detalle del día.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(TvDiscountsDayDialog), findsOneWidget);
      expect(find.textContaining('Tope \$7.500 por mes'), findsOneWidget);
    });
  });
}
