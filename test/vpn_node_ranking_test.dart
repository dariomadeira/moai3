import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/vpn_nodes.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const a = VpnNode(
    id: 'a',
    asset: 'a.ovpn',
    provider: VpnProvider.proton,
    country: 'MX',
  );
  const b = VpnNode(
    id: 'b',
    asset: 'b.ovpn',
    provider: VpnProvider.proton,
    country: 'MX',
  );
  const c = VpnNode(
    id: 'c',
    asset: 'c.ovpn',
    provider: VpnProvider.vpnGate,
    country: 'JP',
  );

  group('VpnNodeRanking', () {
    test('la nota sube con cada éxito y baja con cada falla', () {
      final now = DateTime(2026, 10, 24);
      var s = const VpnNodeStats();
      s = VpnNodeRanking.update(s, attempt: VpnAttempt.success, now: now);
      expect(s.score, closeTo(0.65, 1e-9));
      s = VpnNodeRanking.update(s, attempt: VpnAttempt.success, now: now);
      expect(s.score, closeTo(0.755, 1e-9));
      s = VpnNodeRanking.update(s, attempt: VpnAttempt.failure, now: now);
      expect(s.score, closeTo(0.5285, 1e-9));
      expect(s.lastUsed, now);
    });

    test('un corte de red no hunde a un nodo bueno', () {
      var s = const VpnNodeStats(score: 0.9);
      s = VpnNodeRanking.update(s, attempt: VpnAttempt.transient);
      // Se acerca a neutro (0,5) sin caer como una falla (0,63).
      expect(s.score, closeTo(0.78, 1e-9));
      expect(s.score, greaterThan(0.7));
    });

    test('el patrón del TV: cortarse al primer intento ya no lo hunde', () {
      // Antes, el primero de cada arranque se anotaba como falla y el
      // segundo como éxito: los dos nodos se iban turnando.
      var first = const VpnNodeStats(score: 0.65);
      var second = const VpnNodeStats(score: 0.6);
      first = VpnNodeRanking.update(first, attempt: VpnAttempt.transient);
      second = VpnNodeRanking.update(second, attempt: VpnAttempt.success);
      final order = VpnNodeRanking.order(
        [a, b],
        {'a': first, 'b': second},
      );
      // El que anduvo pasa adelante, pero el cortado sigue arriba de neutro.
      expect(order.first, b);
      expect(first.score, greaterThan(VpnNodeRanking.neutralScore));
    });

    test('un nodo que nunca contesta queda detrás de uno que anda', () {
      var mute = const VpnNodeStats();
      var good = const VpnNodeStats();
      for (var i = 0; i < 5; i++) {
        mute = VpnNodeRanking.update(mute, attempt: VpnAttempt.transient);
        good = VpnNodeRanking.update(good, attempt: VpnAttempt.success);
      }
      expect(
        VpnNodeRanking.order([a, b], {'a': mute, 'b': good}).first,
        b,
      );
    });

    test('el tiempo promedio solo cambia cuando sirvió', () {
      var s = VpnNodeRanking.update(
        const VpnNodeStats(),
        attempt: VpnAttempt.success,
        elapsed: const Duration(seconds: 10),
      );
      expect(s.avgMs, 10000);
      s = VpnNodeRanking.update(
        s,
        attempt: VpnAttempt.success,
        elapsed: const Duration(seconds: 20),
      );
      expect(s.avgMs, closeTo(13000, 1e-9));
      s = VpnNodeRanking.update(
        s,
        attempt: VpnAttempt.failure,
        elapsed: const Duration(seconds: 60),
      );
      expect(s.avgMs, closeTo(13000, 1e-9));
    });

    test('ordena por nota; los nunca usados quedan en 0,5', () {
      final ordered = VpnNodeRanking.order([a, b, c], {
        'a': const VpnNodeStats(score: 0.35),
        'b': const VpnNodeStats(score: 0.76),
      });
      expect(ordered, [b, c, a]);
    });

    test('con notas casi iguales gana el más rápido', () {
      final ordered = VpnNodeRanking.order([a, b], {
        'a': const VpnNodeStats(score: 0.70, avgMs: 15000),
        'b': const VpnNodeStats(score: 0.68, avgMs: 9000),
      });
      expect(ordered, [b, a]);
    });

    test('la exploración pone primero al nodo usado hace más tiempo', () {
      final stats = {
        'a': VpnNodeStats(score: 0.9, lastUsed: DateTime(2026, 10, 24)),
        'b': VpnNodeStats(score: 0.6, lastUsed: DateTime(2026, 10, 20)),
        'c': VpnNodeStats(score: 0.4, lastUsed: DateTime(2026, 10, 22)),
      };
      expect(VpnNodeRanking.order([a, b, c], stats), [a, b, c]);
      expect(
        VpnNodeRanking.order([a, b, c], stats, explore: true),
        [b, a, c],
      );
    });

    test('la exploración prefiere un nodo nunca usado', () {
      final stats = {
        'a': VpnNodeStats(score: 0.9, lastUsed: DateTime(2026, 10, 24)),
        'b': VpnNodeStats(score: 0.6, lastUsed: DateTime(2026, 10, 2)),
      };
      expect(
        VpnNodeRanking.order([a, b, c], stats, explore: true).first,
        c,
      );
    });

    test('record guarda el historial entre arranques', () async {
      SharedPreferences.setMockInitialValues({});
      final ranking = VpnNodeRanking(nodes: [a, b]);
      await ranking.record(a, attempt: VpnAttempt.failure);
      await ranking.record(b, attempt: VpnAttempt.success);
      final stats = await VpnNodeRanking(nodes: [a, b]).load();
      expect(stats['a']!.score, closeTo(0.35, 1e-9));
      expect(stats['b']!.score, closeTo(0.65, 1e-9));
      expect(VpnNodeRanking.order([a, b], stats), [b, a]);
    });

    test('todos los nodos de la app tienen id único y su archivo', () {
      final ids = kVpnNodes.map((n) => n.id).toSet();
      expect(ids.length, kVpnNodes.length);
      for (final node in kVpnNodes) {
        expect(node.asset, startsWith('assets/vpn/'));
      }
    });
  });
}
