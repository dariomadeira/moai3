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
      s = VpnNodeRanking.update(s, success: true, now: now);
      expect(s.score, closeTo(0.65, 1e-9));
      s = VpnNodeRanking.update(s, success: true, now: now);
      expect(s.score, closeTo(0.755, 1e-9));
      s = VpnNodeRanking.update(s, success: false, now: now);
      expect(s.score, closeTo(0.5285, 1e-9));
      expect(s.lastUsed, now);
    });

    test('el tiempo promedio solo cambia cuando sirvió', () {
      var s = VpnNodeRanking.update(
        const VpnNodeStats(),
        success: true,
        elapsed: const Duration(seconds: 10),
      );
      expect(s.avgMs, 10000);
      s = VpnNodeRanking.update(
        s,
        success: true,
        elapsed: const Duration(seconds: 20),
      );
      expect(s.avgMs, closeTo(13000, 1e-9));
      s = VpnNodeRanking.update(
        s,
        success: false,
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
      await ranking.record(a, success: false);
      await ranking.record(b, success: true);
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
