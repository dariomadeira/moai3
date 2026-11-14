import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/vpn_nodes.dart';
import 'package:moai3/services/vpn_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const a = VpnNode(
    id: 'a',
    asset: 'a.ovpn',
    provider: VpnProvider.proton,
    country: 'MX',
    host: '10.0.0.1',
    ports: [(VpnProto.udp, 1194), (VpnProto.udp, 80), (VpnProto.tcp, 443)],
  );
  const b = VpnNode(
    id: 'b',
    asset: 'b.ovpn',
    provider: VpnProvider.proton,
    country: 'MX',
    host: '10.0.0.2',
    ports: [(VpnProto.udp, 1194), (VpnProto.udp, 80), (VpnProto.tcp, 443)],
  );
  const c = VpnNode(
    id: 'c',
    asset: 'c.ovpn',
    provider: VpnProvider.vpnGate,
    country: 'JP',
    host: 'vpn.example.net',
    ports: [(VpnProto.tcp, 443)],
  );

  const a1194 = VpnEndpoint(a, VpnProto.udp, 1194);
  const a80 = VpnEndpoint(a, VpnProto.udp, 80);
  const a443 = VpnEndpoint(a, VpnProto.tcp, 443);
  const b1194 = VpnEndpoint(b, VpnProto.udp, 1194);
  const b80 = VpnEndpoint(b, VpnProto.udp, 80);
  const c443 = VpnEndpoint(c, VpnProto.tcp, 443);

  final now = DateTime(2026, 11, 2, 12);

  VpnEndpointStats run(List<VpnAttempt> attempts, {DateTime? at}) {
    var s = const VpnEndpointStats();
    for (final x in attempts) {
      s = VpnNodeRanking.update(s, attempt: x, now: at ?? now);
    }
    return s;
  }

  group('VpnNodeRanking', () {
    test('sin historial la tasa es neutra y un resultado no la extrema', () {
      expect(const VpnEndpointStats().score, VpnNodeRanking.neutralScore);
      expect(run([VpnAttempt.success]).score, closeTo(2 / 3, 1e-9));
      expect(run([VpnAttempt.failure]).score, closeTo(1 / 3, 1e-9));
    });

    test('un corte de red no cuenta como intento', () {
      final s = run([VpnAttempt.success, VpnAttempt.transient]);
      expect(s.tries, 1);
      expect(s.wins, 1);
      expect(s.failStreak, 0);
    });

    test('lo viejo se olvida con la vida media', () {
      final old = run([
        VpnAttempt.failure,
        VpnAttempt.failure,
        VpnAttempt.failure,
        VpnAttempt.failure,
      ], at: now.subtract(VpnNodeRanking.halfLife));
      final d = old.decayed(now);
      expect(d.tries, closeTo(2, 1e-6));
      // Vuelve hacia neutro: 1/(2+2) = 0,25 en vez de 1/6.
      expect(d.score, closeTo(0.25, 1e-6));
      expect(d.score, greaterThan(old.score));
    });

    test('el orden de fábrica alterna servidores y puertos', () {
      final order = VpnNodeRanking.defaultOrder([a, b, c]);
      // a arranca por su 1.er puerto, b (mismo proveedor) por el 2.º.
      expect(order.take(3), [a1194, b80, c443]);
      expect(order.toSet().length, 7);
    });

    test('los nodos de la app arrancan por servidores, puertos y '
        'proveedores distintos', () {
      final first = VpnNodeRanking.defaultOrder(kVpnNodes).take(4).toList();
      expect(first.map((e) => e.node.id).toSet().length, 4);
      expect(first.map((e) => e.port).toSet().length, greaterThan(1));
      expect(first.map((e) => e.node.provider).toSet().length, 2);
    });

    test('el último que anduvo va primero aunque tenga menos tasa', () {
      final stats = {
        a1194.id: run([
          VpnAttempt.success,
          VpnAttempt.success,
          VpnAttempt.success,
        ], at: now.subtract(const Duration(days: 2))),
        b80.id: run([VpnAttempt.failure, VpnAttempt.success]),
      };
      final order = VpnNodeRanking.order(
        VpnNodeRanking.defaultOrder([a, b, c]),
        stats,
        now: now,
      );
      expect(order.first, b80);
      expect(order[1], a1194);
    });

    test('con dos fallas seguidas el último bueno pierde el primer '
        'puesto', () {
      final stats = {
        a1194.id: run([
          VpnAttempt.success,
          VpnAttempt.success,
          VpnAttempt.success,
        ], at: now.subtract(const Duration(days: 1))),
        b80.id: run([
          VpnAttempt.success,
          VpnAttempt.failure,
          VpnAttempt.failure,
        ]),
      };
      final order = VpnNodeRanking.order(
        VpnNodeRanking.defaultOrder([a, b, c]),
        stats,
        now: now,
      );
      expect(order.first, a1194);
      expect(order.last, b80);
    });

    test('una falla suelta no lo saca del primer puesto', () {
      final stats = {
        a80.id: run([
          VpnAttempt.success,
          VpnAttempt.success,
          VpnAttempt.failure,
        ]),
      };
      final order = VpnNodeRanking.order(
        VpnNodeRanking.defaultOrder([a, b, c]),
        stats,
        now: now,
      );
      expect(order.first, a80);
    });

    test('con tasas casi iguales gana el más rápido', () {
      final order = VpnNodeRanking.order(
        [a1194, b1194],
        {
          a1194.id: VpnEndpointStats(
            wins: 5,
            tries: 6,
            avgMs: 15000,
            lastUsed: now,
          ),
          b1194.id: VpnEndpointStats(
            wins: 4.9,
            tries: 6,
            avgMs: 9000,
            lastUsed: now,
          ),
        },
        now: now,
      );
      expect(order, [b1194, a1194]);
    });

    test('la cola no tiene tope: sin fallas pasan todos en orden', () {
      final queue = VpnAttemptQueue([a1194, a80, b1194, c443]);
      final seen = <VpnEndpoint>[];
      while (queue.isNotEmpty) {
        seen.add(queue.next());
      }
      expect(seen, [a1194, a80, b1194, c443]);
    });

    test('sin respuesta: los otros puertos del servidor pasan al final', () {
      final queue = VpnAttemptQueue([a1194, a80, a443, b1194, c443]);
      queue.failed(queue.next(), VpnFailure.noAnswer);
      expect(queue.pending, [b1194, c443, a80, a443]);
    });

    test('sin respuesta tres veces: el servidor se da por caído', () {
      final queue = VpnAttemptQueue([a1194, a80, a443, b1194]);
      queue.failed(queue.next(), VpnFailure.noAnswer); // a1194
      expect(queue.pending, [b1194, a80, a443]);
      queue.next(); // b1194 (anduvo o no, no importa acá)
      queue.failed(queue.next(), VpnFailure.noAnswer); // a80
      expect(queue.pending, [a443]);
      queue.failed(queue.next(), VpnFailure.noAnswer); // a443: la tercera
      expect(queue.isEmpty, isTrue);
    });

    test('autenticación rechazada: fuera sus otros puertos y un reintento '
        'al final', () {
      final queue = VpnAttemptQueue([a1194, a80, b1194, c443]);
      queue.failed(queue.next(), VpnFailure.auth);
      expect(queue.pending, [b1194, c443, a1194]);
      // Los demás también pasan; el reintento es uno solo.
      queue.failed(queue.next(), VpnFailure.auth); // b1194
      queue.failed(queue.next(), VpnFailure.auth); // c443
      expect(queue.pending, [a1194, b1194, c443]);
      queue.failed(queue.next(), VpnFailure.auth); // a1194 otra vez
      expect(queue.pending, [b1194, c443]);
    });

    test('si el portal rechaza la salida se descarta el servidor', () {
      final queue = VpnAttemptQueue([a1194, a80, b1194, a443, c443]);
      queue.failed(queue.next(), VpnFailure.region);
      expect(queue.pending, [b1194, c443]);
    });

    test('sin sesión: los otros puertos del servidor pasan al final', () {
      final queue = VpnAttemptQueue([a1194, a80, b1194]);
      queue.failed(queue.next(), VpnFailure.session);
      expect(queue.pending, [b1194, a80]);
    });

    test('recordAll guarda el historial entre arranques', () async {
      SharedPreferences.setMockInitialValues({'vpn_node_ranking_v2': '{}'});
      final ranking = VpnNodeRanking(nodes: [a, b]);
      await ranking.recordAll([
        (endpoint: a1194, attempt: VpnAttempt.failure, elapsed: null),
        (
          endpoint: b80,
          attempt: VpnAttempt.success,
          elapsed: const Duration(seconds: 9),
        ),
      ]);
      final stats = await VpnNodeRanking(nodes: [a, b]).load();
      expect(stats[a1194.id]!.failStreak, 1);
      expect(stats[b80.id]!.avgMs, 9000);
      expect(stats[b80.id]!.lastWin, isNotNull);
      expect((await ranking.orderedEndpoints()).first, b80);
      // El historial por nodo de antes se borra.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('vpn_node_ranking_v2'), isFalse);
    });

    test('todos los nodos de la app tienen id único, archivo y puertos', () {
      final ids = kVpnNodes.map((n) => n.id).toSet();
      expect(ids.length, kVpnNodes.length);
      for (final node in kVpnNodes) {
        expect(node.asset, startsWith('assets/vpn/'));
        expect(node.endpoints, isNotEmpty);
      }
    });
  });

  group('VpnService.configFor', () {
    const ovpn =
        'client\r\n'
        'dev tun\r\n'
        'proto udp\r\n'
        'remote 10.0.0.1 5060\r\n'
        'remote 10.0.0.1 1194\r\n'
        'remote-random\r\n'
        'explicit-exit-notify\r\n'
        'remote-cert-tls server\r\n'
        '<ca>\r\nAAAA\r\n</ca>\r\n';

    test('deja un solo remote, el del endpoint', () {
      final cfg = VpnService.configFor(ovpn, a1194);
      final lines = cfg.split('\n').map((l) => l.trim()).toList();
      expect(lines.where((l) => l.startsWith('remote ')), [
        'remote 10.0.0.1 1194',
      ]);
      expect(lines, isNot(contains('remote-random')));
      expect(lines.where((l) => l.startsWith('proto ')), ['proto udp']);
      // No toca lo que sólo empieza parecido ni los bloques del certificado.
      expect(lines, contains('remote-cert-tls server'));
      expect(lines, contains('AAAA'));
      expect(lines, contains('explicit-exit-notify'));
    });

    test('en TCP cambia el protocolo y saca lo que sólo vale en UDP', () {
      final cfg = VpnService.configFor(ovpn, a443);
      final lines = cfg.split('\n').map((l) => l.trim()).toList();
      expect(lines.where((l) => l.startsWith('proto ')), ['proto tcp']);
      expect(lines, contains('remote 10.0.0.1 443'));
      expect(lines, isNot(contains('explicit-exit-notify')));
    });
  });

  test('los .ovpn de la app apuntan al servidor declarado en su nodo', () {
    // Si se reemplaza un .ovpn por otro servidor hay que actualizar el host.
    for (final node in kVpnNodes) {
      final text = File(node.asset).readAsStringSync();
      expect(
        RegExp(
          '^remote ${RegExp.escape(node.host)} ',
          multiLine: true,
        ).hasMatch(text),
        isTrue,
        reason: node.id,
      );
    }
  });
}
