import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cómo se autentica cada proveedor de VPN.
enum VpnProvider {
  /// Usuario y contraseña de `.env`, con el selector de salida `+b:0`.
  proton,

  /// Certificado incluido en el `.ovpn`, sin usuario (VPN Gate / opengw.net).
  vpnGate,
}

/// Un perfil OpenVPN del arranque.
@immutable
class VpnNode {
  const VpnNode({
    required this.id,
    required this.asset,
    required this.provider,
    required this.country,
  });

  final String id;
  final String asset;
  final VpnProvider provider;

  /// Código ISO del país de salida esperado (`verifyConnection`).
  final String country;

  @override
  String toString() => id;
}

/// Nodos disponibles. Agregar uno = sumar el `.ovpn` en `assets/vpn/` y una línea acá.
const List<VpnNode> kVpnNodes = [
  VpnNode(
    id: 'mx_01',
    asset: 'assets/vpn/mexico_01.ovpn',
    provider: VpnProvider.proton,
    country: 'MX',
  ),
  VpnNode(
    id: 'mx_02',
    asset: 'assets/vpn/mexico_02.ovpn',
    provider: VpnProvider.proton,
    country: 'MX',
  ),
  VpnNode(
    id: 'mx_03',
    asset: 'assets/vpn/mexico_03.ovpn',
    provider: VpnProvider.proton,
    country: 'MX',
  ),
  VpnNode(
    id: 'mx_04',
    asset: 'assets/vpn/mexico_04.ovpn',
    provider: VpnProvider.proton,
    country: 'MX',
  ),
  VpnNode(
    id: 'jp_01',
    asset: 'assets/vpn/japan_01.ovpn',
    provider: VpnProvider.vpnGate,
    country: 'JP',
  ),
  VpnNode(
    id: 'jp_02',
    asset: 'assets/vpn/japan_02.ovpn',
    provider: VpnProvider.vpnGate,
    country: 'JP',
  ),
];

/// Cómo le fue a un intento con un nodo.
enum VpnAttempt {
  /// Conectó y dio sesión.
  success,

  /// Falla del nodo: no conectó, salió por otro país o el portal lo rechazó.
  failure,

  /// La red no contestó a tiempo (pasa apenas sube el túnel, con cualquier
  /// nodo): no dice si el nodo es bueno o malo.
  transient,
}

/// Historial de un nodo en este dispositivo.
@immutable
class VpnNodeStats {
  const VpnNodeStats({
    this.score = VpnNodeRanking.neutralScore,
    this.avgMs,
    this.lastUsed,
  });

  /// 0 a 1: qué tan seguido sirvió últimamente.
  final double score;

  /// Tiempo promedio hasta la sesión lista; null si nunca sirvió.
  final double? avgMs;

  final DateTime? lastUsed;

  factory VpnNodeStats.fromJson(Map<String, dynamic> json) => VpnNodeStats(
        score: (json['score'] as num?)?.toDouble() ?? VpnNodeRanking.neutralScore,
        avgMs: (json['avgMs'] as num?)?.toDouble(),
        lastUsed: DateTime.tryParse(json['lastUsed'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'score': score,
        if (avgMs != null) 'avgMs': avgMs,
        if (lastUsed != null) 'lastUsed': lastUsed!.toIso8601String(),
      };
}

/// Aprende qué nodo anda mejor en este TV y lo prueba primero.
/// Cada resultado pesa 30 %; lo anterior, 70 % (lo reciente manda). Un
/// corte pasajero ([VpnAttempt.transient]) cuenta como empate: no hunde a un
/// nodo bueno por la red, pero uno que nunca contesta va bajando a neutro.
class VpnNodeRanking {
  VpnNodeRanking({this.nodes = kVpnNodes, Random? random})
      : _random = random ?? Random();

  static const double neutralScore = 0.5;
  static const double _keep = 0.7;

  /// Notas a menos de esto se consideran empate y gana el más rápido.
  static const double _tie = 0.05;

  /// Parte de los arranques en que el primer intento va al nodo menos usado.
  static const double explorationRate = 0.1;

  /// v2: el historial anterior anotaba los cortes de red como fallas del
  /// nodo (castigaba al primero de cada arranque); se empieza de cero.
  static const String _prefsKey = 'vpn_node_ranking_v2';

  final List<VpnNode> nodes;
  final Random _random;

  Future<Map<String, VpnNodeStats>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (id, value) => MapEntry(
          id,
          VpnNodeStats.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ [VPN] No se pudo leer el ranking: $e');
      return {};
    }
  }

  Future<void> _save(Map<String, VpnNodeStats> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(stats.map((id, s) => MapEntry(id, s.toJson()))),
    );
  }

  /// Nodos en el orden en que conviene probarlos en este arranque.
  Future<List<VpnNode>> orderedNodes() async {
    final stats = await load();
    final ordered = order(
      nodes,
      stats,
      explore: _random.nextDouble() < explorationRate,
    );
    debugPrint(
      '🔒 [VPN] Ranking: ${ordered.map((n) {
        final s = stats[n.id];
        return '${n.id}=${(s?.score ?? neutralScore).toStringAsFixed(2)}';
      }).join(' > ')}',
    );
    return ordered;
  }

  /// Orden por nota (empates por velocidad). Con [explore], el nodo usado
  /// hace más tiempo (o nunca) pasa al frente.
  @visibleForTesting
  static List<VpnNode> order(
    List<VpnNode> nodes,
    Map<String, VpnNodeStats> stats, {
    bool explore = false,
  }) {
    VpnNodeStats statsOf(VpnNode n) => stats[n.id] ?? const VpnNodeStats();
    final ordered = [...nodes]..sort((a, b) {
        final sa = statsOf(a), sb = statsOf(b);
        if ((sa.score - sb.score).abs() >= _tie) {
          return sb.score.compareTo(sa.score);
        }
        return (sa.avgMs ?? double.infinity)
            .compareTo(sb.avgMs ?? double.infinity);
      });
    if (explore && ordered.length > 1) {
      final stalest = ordered.reduce((a, b) {
        final la = statsOf(a).lastUsed, lb = statsOf(b).lastUsed;
        if (la == null) return a;
        if (lb == null) return b;
        return la.isBefore(lb) ? a : b;
      });
      debugPrint('🔒 [VPN] Exploración: primero $stalest');
      ordered
        ..remove(stalest)
        ..insert(0, stalest);
    }
    return ordered;
  }

  /// Anota el resultado de un intento con [node].
  Future<void> record(
    VpnNode node, {
    required VpnAttempt attempt,
    Duration? elapsed,
  }) async {
    final stats = await load();
    stats[node.id] = update(
      stats[node.id] ?? const VpnNodeStats(),
      attempt: attempt,
      elapsed: elapsed,
    );
    await _save(stats);
    final verb = switch (attempt) {
      VpnAttempt.success => 'sirvió',
      VpnAttempt.failure => 'falló',
      VpnAttempt.transient => 'tuvo un corte de red',
    };
    debugPrint(
      '🔒 [VPN] ${node.id} $verb '
      '→ nota ${stats[node.id]!.score.toStringAsFixed(2)}',
    );
  }

  @visibleForTesting
  static VpnNodeStats update(
    VpnNodeStats old, {
    required VpnAttempt attempt,
    Duration? elapsed,
    DateTime? now,
  }) {
    final ms = elapsed?.inMilliseconds.toDouble();
    final success = attempt == VpnAttempt.success;
    final outcome = switch (attempt) {
      VpnAttempt.success => 1.0,
      VpnAttempt.failure => 0.0,
      VpnAttempt.transient => neutralScore,
    };
    return VpnNodeStats(
      score: _keep * old.score + (1 - _keep) * outcome,
      avgMs: success && ms != null
          ? (old.avgMs == null ? ms : _keep * old.avgMs! + (1 - _keep) * ms)
          : old.avgMs,
      lastUsed: now ?? DateTime.now(),
    );
  }
}
