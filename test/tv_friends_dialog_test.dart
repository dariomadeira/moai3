import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/dialogs/tv_friends_dialog.dart';
import 'package:moai3/widgets/tv_common/moai_count_badge.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_value_chip.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/real_fonts.dart';
import 'helpers/spanish_translations.dart';
import 'watch_party_provider_test.dart' show FakeWatchPartyService;

void main() {
  setUpAll(loadRealFonts);

  FriendInfo friend(String id, String name, {bool online = false}) =>
      FriendInfo(
        deviceId: id,
        userCode: 'MOAI-${id.toUpperCase()}',
        nickname: name,
        isOnline: online,
      );

  /// Ana me agregó de vuelta (amiga, conectada); Beto todavía no (enviada);
  /// Caro me agregó y yo no (recibida).
  FakeWatchPartyService service() => FakeWatchPartyService()
    ..mockFriends = [friend('ana', 'Ana', online: true), friend('beto', 'Beto')]
    ..mockRequests = [friend('caro', 'Caro')]
    ..mockIncoming = {'ana', 'caro'};

  Future<WatchPartyProvider> provider(FakeWatchPartyService service) async {
    SharedPreferences.setMockInitialValues({
      'device_user_code': 'MOAI-1234',
      'device_id': 'tv-1',
    });
    final prefs = await AppPreferences.init();
    return WatchPartyProvider(
      preferences: prefs,
      service: service,
      identityService: DeviceIdentityService(prefs),
    );
  }

  group('WatchPartyProvider: amigos y enviadas', () {
    test('separa los que me agregaron de vuelta de los que no', () async {
      final watchParty = await provider(service());
      await watchParty.loadFriends();
      expect(watchParty.mutualFriends.map((f) => f.nickname), ['Ana']);
      expect(watchParty.sentRequests.map((f) => f.nickname), ['Beto']);
      // [friends] sigue siendo todos (lo usan el Inicio y Arcade).
      expect(watchParty.friends, hasLength(2));
    });

    test('sin saber quién me agregó, todos cuentan como amigos', () async {
      final watchParty = await provider(service()..mockIncoming = null);
      await watchParty.loadFriends();
      expect(watchParty.mutualFriends, hasLength(2));
      expect(watchParty.sentRequests, isEmpty);
    });
  });

  group('TvFriendsDialog', () {
    /// Abre el modal en cristal y a tamaño de TV (960×540 puntos).
    Future<void> open(
      WidgetTester tester,
      WatchPartyProvider watchParty,
    ) async {
      useSpanishTranslations();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: watchParty,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => TvFriendsDialog.show(context),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
    }

    /// La fila con [text] tiene el foco.
    bool focusedRow(WidgetTester tester, String text) =>
        Focus.of(tester.element(find.text(text))).hasPrimaryFocus;

    String? focused() => FocusManager.instance.primaryFocus?.debugLabel;

    testWidgets('recorre los tres paneles con ←/→ y ↑/↓', (tester) async {
      final svc = service();
      final watchParty = await provider(svc);
      await open(tester, watchParty);

      // Abre en Amigos: Ana (conectada), no Beto (todavía no te agregó).
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Beto'), findsNothing);
      expect(focusedRow(tester, 'Ana'), isTrue);
      expect(find.text('1 EN LÍNEA'), findsOneWidget);
      // Contador de las pestañas: sólo la solicitud recibida (los conectados
      // ya los dice la etiqueta de arriba).
      expect(
        tester
            .widgetList<MoaiCountBadge>(find.byType(MoaiCountBadge))
            .map((b) => b.count),
        [1],
      );

      // → Solicitudes: sólo las recibidas (la enviada a Beto no figura).
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(find.text('Caro'), findsOneWidget);
      expect(find.text('Beto'), findsNothing);
      expect(find.text('Quiere ser tu amigo'), findsOneWidget);
      // El código, con la pastilla de cristal de Ajustes.
      expect(find.widgetWithText(TvValueChip, 'MOAI-CARO'), findsOneWidget);
      expect(find.text('OK: aceptar · Mantené OK: rechazar'), findsOneWidget);
      expect(focusedRow(tester, 'Caro'), isTrue);

      // ↓ desde la última: Cerrar; ↑ vuelve al panel.
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'friends_modal_close_btn');
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(focusedRow(tester, 'Caro'), isTrue);

      // → Agregar y buscar: el campo del código (ya no muestra el tuyo).
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(find.text('Buscar por apodo'), findsOneWidget);
      expect(find.text('Tu código'), findsNothing);
      expect(focused(), 'friends_modal_code_input');

      // ← vuelve a Solicitudes y a Amigos, donde había quedado.
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(focusedRow(tester, 'Caro'), isTrue);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(focusedRow(tester, 'Ana'), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('aceptar una solicitud la pasa a Amigos', (tester) async {
      final svc = service()..mockRequests = [friend('caro', 'Caro')];
      final watchParty = await provider(svc);
      await open(tester, watchParty);

      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.enter);
      // El fake la agrega como amiga; la recibida desaparece.
      expect(svc.mockRequests, isEmpty);
      expect(find.text('Quiere ser tu amigo'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    // Los paneles cerrados quedan armados (sin foco): pasar de panel tras
    // haber estado en Cerrar, o volver a uno ya visitado, no debe mandar el
    // foco a Cerrar.
    testWidgets('el foco recorre los paneles ida y vuelta, también tras '
        'pasar por Cerrar', (tester) async {
      final watchParty = await provider(service());
      await open(tester, watchParty);
      const r = LogicalKeyboardKey.arrowRight;
      const l = LogicalKeyboardKey.arrowLeft;
      const d = LogicalKeyboardKey.arrowDown;
      const u = LogicalKeyboardKey.arrowUp;

      expect(focusedRow(tester, 'Ana'), isTrue);
      await press(tester, d);
      expect(focused(), 'friends_modal_close_btn');
      await press(tester, u);
      await press(tester, r);
      expect(focusedRow(tester, 'Caro'), isTrue);
      await press(tester, d);
      await press(tester, u);
      await press(tester, r);
      expect(focused(), 'friends_modal_code_input');
      await press(tester, r);
      expect(focused(), 'friends_modal_add_btn');
      await press(tester, l);
      await press(tester, l);
      expect(focusedRow(tester, 'Caro'), isTrue);
      await press(tester, l);
      expect(focusedRow(tester, 'Ana'), isTrue);
      await press(tester, r);
      await press(tester, r);
      expect(focused(), 'friends_modal_code_input');
      expect(tester.takeException(), isNull);
    });

    testWidgets('sin datos el foco va de estado vacío en estado vacío', (
      tester,
    ) async {
      final watchParty = await provider(
        FakeWatchPartyService()..mockIncoming = {},
      );
      await open(tester, watchParty);
      const r = LogicalKeyboardKey.arrowRight;
      const l = LogicalKeyboardKey.arrowLeft;

      expect(focused(), 'friends_modal_empty_0');
      await press(tester, r);
      expect(focused(), 'friends_modal_empty_1');
      await press(tester, r);
      expect(focused(), 'friends_modal_code_input');
      await press(tester, l);
      expect(focused(), 'friends_modal_empty_1');
      await press(tester, l);
      expect(focused(), 'friends_modal_empty_0');
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, r);
      expect(focused(), 'friends_modal_empty_1');
      expect(tester.takeException(), isNull);
    });

    /// Escribe [text] en el campo de [label] como si viniera del teclado.
    Future<void> submit(WidgetTester tester, String label, String text) async {
      final field = tester.widget<TvTextField>(
        find.byWidgetPredicate(
          (w) => w is TvTextField && w.focusNode?.debugLabel == label,
        ),
      );
      field.controller!.text = text;
      field.onSubmitted!(text);
      await tester.pumpAndSettle();
    }

    testWidgets('buscar por apodo y mandar la solicitud al elegido', (
      tester,
    ) async {
      final svc = service()
        ..mockSearch = [
          friend('magu', 'Magui', online: true),
          friend('mari', 'Mariano'),
          friend('ana', 'Ana María', online: true),
        ];
      final watchParty = await provider(svc);
      await open(tester, watchParty);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'friends_modal_search_input');

      await submit(tester, 'friends_modal_search_input', 'ma');
      // Trae la lista y el foco baja al primero.
      expect(find.text('Magui'), findsOneWidget);
      expect(find.text('Mariano'), findsOneWidget);
      expect(focusedRow(tester, 'Magui'), isTrue);
      expect(find.text('Mandale una solicitud'), findsNWidgets(2));
      expect(find.text('OK: mandar solicitud'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.enter);
      await tester.pump();
      expect(svc.mockFriends.map((f) => f.userCode), contains('MOAI-MAGU'));
      expect(
        find.textContaining('Le mandaste una solicitud a'),
        findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // ↑ desde el primero vuelve al campo de buscar; ↑ otra vez, al código.
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(focused(), 'friends_modal_search_input');
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(focused(), 'friends_modal_code_input');
      expect(tester.takeException(), isNull);
    });

    /// El estado vacío que ocupa el lugar de los resultados.
    Finder searchEmpty(String text) => find.descendant(
      of: find.byType(TvEmptyStateCard),
      matching: find.text(text),
    );

    testWidgets('buscar sin resultados muestra el estado vacío en la lista', (
      tester,
    ) async {
      final watchParty = await provider(service());
      await open(tester, watchParty);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowDown); // al buscador

      await submit(tester, 'friends_modal_search_input', 'zz');
      expect(searchEmpty('No encontramos a nadie con «zz».'), findsOneWidget);
      // ↓ desde el buscador va al estado vacío; ↓ otra vez, a Cerrar.
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'friends_modal_search_empty');
      await press(tester, LogicalKeyboardKey.arrowDown);
      expect(focused(), 'friends_modal_close_btn');
      expect(tester.takeException(), isNull);
    });

    testWidgets('con menos de 2 letras lo dice en la lista, no abajo en rojo', (
      tester,
    ) async {
      final watchParty = await provider(service());
      await open(tester, watchParty);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowRight);

      await submit(tester, 'friends_modal_search_input', 'b');
      expect(searchEmpty('Escribí al menos 2 letras.'), findsOneWidget);
      // Sin el aviso rojo de error debajo del acordeón.
      expect(find.byIcon(MoaiIcons.error), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el D-pad recorre los resultados y vuelve sin saltos', (
      tester,
    ) async {
      final names = ['Bua', 'Bub', 'Buc', 'Bud', 'Bue'];
      final svc = service()
        ..mockSearch = [for (final n in names) friend(n.toLowerCase(), n)];
      final watchParty = await provider(svc);
      await open(tester, watchParty);
      const r = LogicalKeyboardKey.arrowRight;
      const l = LogicalKeyboardKey.arrowLeft;
      const d = LogicalKeyboardKey.arrowDown;
      const u = LogicalKeyboardKey.arrowUp;
      await press(tester, r);
      await press(tester, r);
      await press(tester, d);
      await submit(tester, 'friends_modal_search_input', 'bu');
      expect(focusedRow(tester, 'Bua'), isTrue);

      // ↓ uno por uno (de a dos a la vista) hasta Cerrar y ↑ de vuelta.
      for (final n in names.skip(1)) {
        await press(tester, d);
        expect(focusedRow(tester, n), isTrue);
      }
      await press(tester, d);
      expect(focused(), 'friends_modal_close_btn');
      // ↑ desde Cerrar vuelve al último resultado, no al principio.
      await press(tester, u);
      expect(focusedRow(tester, 'Bue'), isTrue);
      for (final n in names.reversed.skip(1)) {
        await press(tester, u);
        expect(focusedRow(tester, n), isTrue);
      }
      await press(tester, u);
      expect(focused(), 'friends_modal_search_input');
      await press(tester, u);
      expect(focused(), 'friends_modal_code_input');

      // Código → Agregar → (↓) la X → (←) buscador → (↓) primer resultado.
      await press(tester, r);
      expect(focused(), 'friends_modal_add_btn');
      await press(tester, d);
      expect(focused(), 'friends_modal_search_clear');
      await press(tester, l);
      expect(focused(), 'friends_modal_search_input');
      await press(tester, d);
      expect(focusedRow(tester, 'Bua'), isTrue);
      // Una tecla que no mueve (→) no dispara un foco atrasado.
      await press(tester, r);
      expect(focusedRow(tester, 'Bua'), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el error de un panel no queda al pasar a otro', (
      tester,
    ) async {
      final watchParty = await provider(service());
      await open(tester, watchParty);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowRight);

      // Agregar sin código: avisa (traducido, una sola vez).
      await submit(tester, 'friends_modal_code_input', '');
      expect(find.text('Ingresa los 4 caracteres del código'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(find.text('Ingresa los 4 caracteres del código'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el buscador no queda pegado al campo del código', (
      tester,
    ) async {
      final watchParty = await provider(service());
      await open(tester, watchParty);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowRight);

      Rect fieldOf(String label) => tester.getRect(
        find.byWidgetPredicate(
          (w) => w is TvTextField && w.focusNode?.debugLabel == label,
        ),
      );
      final code = fieldOf('friends_modal_code_input');
      final search = fieldOf('friends_modal_search_input');
      expect(search.top - code.bottom, greaterThanOrEqualTo(10));
      expect(tester.takeException(), isNull);
    });

    testWidgets('la X borra la búsqueda y vuelve al buscador', (tester) async {
      final svc = service()..mockSearch = [friend('bubu', 'Bubu')];
      final watchParty = await provider(svc);
      await open(tester, watchParty);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.arrowRight);

      await submit(tester, 'friends_modal_search_input', 'bu');
      expect(find.text('Bubu'), findsOneWidget);
      // ↑ al buscador, → a la X, OK.
      await press(tester, LogicalKeyboardKey.arrowUp);
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(focused(), 'friends_modal_search_clear');
      await press(tester, LogicalKeyboardKey.enter);

      expect(find.text('Bubu'), findsNothing);
      expect(focused(), 'friends_modal_search_input');
      final field = tester.widget<TvTextField>(
        find.byWidgetPredicate(
          (w) =>
              w is TvTextField &&
              w.focusNode?.debugLabel == 'friends_modal_search_input',
        ),
      );
      expect(field.controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('las listas quedan con el mismo espacio arriba y abajo', (
      tester,
    ) async {
      final svc = service()
        ..mockRequests = [
          for (final n in ['Caro', 'Dani', 'Eli', 'Fede'])
            friend(n.toLowerCase(), n),
        ];
      final watchParty = await provider(svc);
      await open(tester, watchParty);
      await press(tester, LogicalKeyboardKey.arrowRight);

      final panel = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is Focus && w.focusNode?.debugLabel == 'friends_modal_panel_1',
        ),
      );
      final first = tester.getRect(
        find
            .ancestor(of: find.text('Caro'), matching: find.byType(MoaiGlass))
            .first,
      );
      final last = tester.getRect(
        find
            .ancestor(of: find.text('Fede'), matching: find.byType(MoaiGlass))
            .first,
      );
      expect(first.top - panel.top, closeTo(panel.bottom - last.bottom, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('OK mantenido rechaza la solicitud tras confirmar', (
      tester,
    ) async {
      final svc = service();
      final watchParty = await provider(svc);
      await open(tester, watchParty);

      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(focusedRow(tester, 'Caro'), isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Pide confirmar; Cancelar enfocado, → Rechazar.
      expect(find.text('Rechazar solicitud'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.enter);

      expect(svc.rejected, ['caro']);
      expect(svc.mockFriends, hasLength(2)); // no la aceptó
      expect(find.text('Caro'), findsNothing);
      expect(focused(), 'friends_modal_empty_1');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'sin amigos ni solicitudes abre en Amigos con el estado vacío',
      (tester) async {
        final svc = FakeWatchPartyService()..mockIncoming = {};
        final watchParty = await provider(svc);
        await open(tester, watchParty);

        expect(focused(), 'friends_modal_empty_0');
        expect(find.byType(TvEmptyStateCard), findsOneWidget);
        // Enfocado: el ícono sigue gris oscuro (no toma el acento).
        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byType(TvEmptyStateCard),
            matching: find.byType(Icon),
          ),
        );
        final scheme = Theme.of(
          tester.element(find.byType(TvEmptyStateCard)),
        ).colorScheme;
        expect(icon.color, scheme.onSurfaceVariant);
        // Mismo título que el ítem de Ajustes y el subtítulo nuevo.
        expect(find.text('Gestionar amigos'), findsOneWidget);
        expect(
          find.text('Ahora puedes mantener contacto con otras personas'),
          findsOneWidget,
        );
        expect(find.byType(MoaiCountBadge), findsNothing);

        // → sigue pasando de panel desde el estado vacío.
        await press(tester, LogicalKeyboardKey.arrowRight);
        expect(focused(), 'friends_modal_empty_1');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('los paneles no tienen título propio', (tester) async {
      final watchParty = await provider(FakeWatchPartyService());
      await open(tester, watchParty);

      // «Amigos» sólo en la pestaña; el título es el del modal.
      expect(find.text('Amigos'), findsOneWidget);
      expect(find.text('Solicitudes de amistad'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('los botones quedan a la derecha', (tester) async {
      final watchParty = await provider(FakeWatchPartyService());
      await open(tester, watchParty);

      final row = tester.widget<Row>(
        find.ancestor(of: find.text('Cerrar'), matching: find.byType(Row)).last,
      );
      expect(row.mainAxisAlignment, MainAxisAlignment.end);
      expect(tester.takeException(), isNull);
    });
  });
}
