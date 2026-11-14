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

/// Protocolo de transporte de un [VpnEndpoint].
enum VpnProto { udp, tcp }

/// Un perfil OpenVPN del arranque: un servidor con los puertos que atiende.
///
/// Del `.ovpn` se usan las claves y el cifrado; el servidor y el puerto los
/// elige la app ([VpnEndpoint]), uno por intento. Con varios `remote` y
/// `remote-random`, OpenVPN probaba un puerto al azar y, si no contestaba,
/// tardaba más que el límite del intento en pasar al siguiente: el mismo
/// nodo andaba o no según el puerto que le tocara.
@immutable
class VpnNode {
  const VpnNode({
    required this.id,
    required this.asset,
    required this.provider,
    required this.country,
    required this.host,
    required this.ports,
  });

  final String id;
  final String asset;
  final VpnProvider provider;

  /// Código ISO del país de salida esperado.
  final String country;

  /// IP o nombre del servidor (el del `remote` del `.ovpn`).
  final String host;

  /// Protocolo y puerto, del que más suele andar al que menos.
  final List<(VpnProto, int)> ports;

  /// Todos sus puntos de conexión, en el orden de preferencia de fábrica.
  List<VpnEndpoint> get endpoints => [
    for (final (proto, port) in ports) VpnEndpoint(this, proto, port),
  ];

  @override
  String toString() => id;
}

/// Un intento posible: nodo, protocolo y puerto.
@immutable
class VpnEndpoint {
  const VpnEndpoint(this.node, this.proto, this.port);

  final VpnNode node;
  final VpnProto proto;
  final int port;

  /// Clave del historial, p. ej. `mx_01/udp1194`.
  String get id => '${node.id}/${proto.name}$port';

  @override
  bool operator ==(Object other) =>
      other is VpnEndpoint &&
      other.node.id == node.id &&
      other.proto == proto &&
      other.port == port;

  @override
  int get hashCode => Object.hash(node.id, proto, port);

  @override
  String toString() => id;
}

/// Puertos de los servidores gratuitos de Proton (los mismos en todos). Los
/// UDP 5060 (SIP) y 51820 (WireGuard) son los que más filtran los routers;
/// el TCP 443 casi nunca se bloquea.
const List<(VpnProto, int)> _protonPorts = [
  (VpnProto.udp, 1194),
  (VpnProto.udp, 80),
  (VpnProto.tcp, 443),
  (VpnProto.udp, 51820),
  (VpnProto.tcp, 8443),
  (VpnProto.udp, 4569),
  (VpnProto.udp, 5060),
];

/// Nodos disponibles. Agregar uno = sumar el `.ovpn` en `assets/vpn/` y una
/// línea acá con su servidor y puertos. El orden de la lista es el de
/// fábrica (sin historial): los japoneses van intercalados para que un
/// primer arranque pruebe también otro proveedor.
const List<VpnNode> kVpnNodes = [
  VpnNode(
    id: 'mx_01',
    asset: 'assets/vpn/mexico_01.ovpn',
    provider: VpnProvider.proton,
    country: 'MX',
    host: '84.20.27.49',
    ports: _protonPorts,
  ),
  VpnNode(
    id: 'mx_02',
    asset: 'assets/vpn/mexico_02.ovpn',
    provider: VpnProvider.proton,
    country: 'MX',
    host: '84.20.27.45',
    ports: _protonPorts,
  ),
  VpnNode(
    id: 'jp_01',
    asset: 'assets/vpn/japan_01.ovpn',
    provider: VpnProvider.vpnGate,
    country: 'JP',
    host: 'public-vpn-137.opengw.net',
    ports: [(VpnProto.tcp, 443)],
  ),
  VpnNode(
    id: 'mx_03',
    asset: 'assets/vpn/mexico_03.ovpn',
    provider: VpnProvider.proton,
    country: 'MX',
    host: '103.88.234.229',
    ports: _protonPorts,
  ),
  VpnNode(
    id: 'mx_04',
    asset: 'assets/vpn/mexico_04.ovpn',
    provider: VpnProvider.proton,
    country: 'MX',
    host: '149.102.224.43',
    ports: _protonPorts,
  ),
  VpnNode(
    id: 'jp_02',
    asset: 'assets/vpn/japan_02.ovpn',
    provider: VpnProvider.vpnGate,
    country: 'JP',
    host: 'public-vpn-90.opengw.net',
    ports: [(VpnProto.tcp, 443)],
  ),
];

/// Cómo le fue a un intento con un endpoint.
enum VpnAttempt {
  /// Conectó y dio sesión.
  success,

  /// Falla del endpoint: el túnel no subió o el portal rechazó la salida.
  failure,

  /// No dice nada del endpoint: la red no contestó apenas subió el túnel, o
  /// falló el catálogo (eso es del servidor). Sólo se anota la fecha.
  transient,
}

/// Historial de un endpoint en este dispositivo.
///
/// Guarda éxitos e intentos que se van olvidando con el tiempo (vida media
/// de [VpnNodeRanking.halfLife]): lo de hace un mes casi no pesa, así un
/// endpoint que falló una vez vuelve solo a ser candidato.
@immutable
class VpnEndpointStats {
  const VpnEndpointStats({
    this.wins = 0,
    this.tries = 0,
    this.avgMs,
    this.lastUsed,
    this.lastWin,
    this.failStreak = 0,
  });

  final double wins;
  final double tries;

  /// Tiempo promedio hasta la sesión lista; null si nunca sirvió.
  final double? avgMs;

  final DateTime? lastUsed;
  final DateTime? lastWin;

  /// Fallas seguidas desde el último éxito.
  final int failStreak;

  /// Tasa de éxito con un intento imaginario bueno y otro malo: sin historial
  /// da 0,5, y un solo resultado no la lleva a los extremos.
  double get score => (wins + 1) / (tries + 2);

  /// Los mismos datos con los conteos olvidados hasta [now].
  VpnEndpointStats decayed(DateTime now) {
    final since = lastUsed;
    if (since == null || !now.isAfter(since)) return this;
    final days = now.difference(since).inMinutes / Duration.minutesPerDay;
    final keep = pow(0.5, days / VpnNodeRanking.halfLife.inDays).toDouble();
    return VpnEndpointStats(
      wins: wins * keep,
      tries: tries * keep,
      avgMs: avgMs,
      lastUsed: lastUsed,
      lastWin: lastWin,
      failStreak: failStreak,
    );
  }

  factory VpnEndpointStats.fromJson(Map<String, dynamic> json) =>
      VpnEndpointStats(
        wins: (json['wins'] as num?)?.toDouble() ?? 0,
        tries: (json['tries'] as num?)?.toDouble() ?? 0,
        avgMs: (json['avgMs'] as num?)?.toDouble(),
        lastUsed: DateTime.tryParse(json['lastUsed'] as String? ?? ''),
        lastWin: DateTime.tryParse(json['lastWin'] as String? ?? ''),
        failStreak: (json['failStreak'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'wins': wins,
    'tries': tries,
    if (avgMs != null) 'avgMs': avgMs,
    if (lastUsed != null) 'lastUsed': lastUsed!.toIso8601String(),
    if (lastWin != null) 'lastWin': lastWin!.toIso8601String(),
    if (failStreak > 0) 'failStreak': failStreak,
  };
}

/// Por qué no sirvió un intento del arranque: de eso depende qué conviene
/// probar después ([VpnAttemptQueue.failed]).
enum VpnFailure {
  /// El servidor contestó y rechazó la autenticación.
  auth,

  /// El túnel no subió: el puerto no contestó o el servidor está caído.
  noAnswer,

  /// El túnel subió pero el portal rechazó la región de esa salida.
  region,

  /// El túnel subió pero no se consiguió la sesión (la red no contestó o
  /// el portal la rechazó por otra cosa).
  session,
}

/// La cola de intentos de un arranque: todos los endpoints en el orden del
/// ranking, sin tope de cantidad. Cada falla la reacomoda según su causa:
///
/// - [VpnFailure.auth]: el servidor contestó, así que sus otros puertos no
///   cambian nada y se sacan; el mismo endpoint vuelve una vez más al final
///   (el rechazo suele ser pasajero: servidor lleno).
/// - [VpnFailure.noAnswer]: sus otros puertos pasan al final (quizá la red
///   bloquea ése); a la [maxNoAnswerPerNode]ª vez se da el servidor por caído.
/// - [VpnFailure.region]: el servidor se descarta (sale por la misma IP).
/// - [VpnFailure.session]: sus otros puertos pasan al final.
class VpnAttemptQueue {
  VpnAttemptQueue(List<VpnEndpoint> ordered) : _queue = [...ordered];

  /// Intentos sin respuesta con los que un servidor se da por caído.
  static const int maxNoAnswerPerNode = 3;

  final List<VpnEndpoint> _queue;
  final Set<VpnEndpoint> _retried = {};
  final Map<String, int> _noAnswer = {};

  bool get isEmpty => _queue.isEmpty;
  bool get isNotEmpty => _queue.isNotEmpty;

  /// Los que quedan, en orden.
  List<VpnEndpoint> get pending => List.unmodifiable(_queue);

  VpnEndpoint next() => _queue.removeAt(0);

  void failed(VpnEndpoint endpoint, VpnFailure failure) {
    bool sibling(VpnEndpoint e) => e.node.id == endpoint.node.id;
    final siblings = _queue.where(sibling).toList();
    _queue.removeWhere(sibling);
    switch (failure) {
      case VpnFailure.auth:
        if (_retried.add(endpoint)) _queue.add(endpoint);
      case VpnFailure.noAnswer:
        final count = (_noAnswer[endpoint.node.id] ?? 0) + 1;
        _noAnswer[endpoint.node.id] = count;
        if (count < maxNoAnswerPerNode) _queue.addAll(siblings);
      case VpnFailure.region:
        break;
      case VpnFailure.session:
        _queue.addAll(siblings);
    }
  }
}

/// Resultado de un intento, para anotarlo al final del arranque.
typedef VpnAttemptResult = ({
  VpnEndpoint endpoint,
  VpnAttempt attempt,
  Duration? elapsed,
});

/// Aprende qué endpoint (nodo + puerto) anda en este TV y lo prueba primero.
///
/// - **El último que anduvo va primero**, salvo que haya fallado
///   [maxFailStreak] veces seguidas.
/// - El resto, por tasa de éxito ([VpnEndpointStats.score]); con tasas casi
///   iguales, el más rápido. Sin historial, el orden de fábrica, que alterna
///   servidores y puertos para probar de todo.
/// - Lo viejo se olvida ([halfLife]): no hace falta exploración al azar.
class VpnNodeRanking {
  VpnNodeRanking({this.nodes = kVpnNodes});

  static const double neutralScore = 0.5;

  /// Tasas a menos de esto se consideran empate y gana el más rápido.
  static const double _tie = 0.05;

  /// Fallas seguidas con las que el último bueno pierde el primer puesto.
  static const int maxFailStreak = 2;

  /// En cuánto tiempo un resultado pesa la mitad.
  static const Duration halfLife = Duration(days: 14);

  /// v3: historial por endpoint (antes, por nodo).
  static const String _prefsKey = 'vpn_endpoint_ranking_v3';
  static const String _legacyPrefsKey = 'vpn_node_ranking_v2';

  final List<VpnNode> nodes;

  Future<Map<String, VpnEndpointStats>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_legacyPrefsKey)) {
        await prefs.remove(_legacyPrefsKey);
      }
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (id, value) => MapEntry(
          id,
          VpnEndpointStats.fromJson(value as Map<String, dynamic>),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ [VPN] No se pudo leer el ranking: $e');
      return {};
    }
  }

  Future<void> _save(Map<String, VpnEndpointStats> stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(stats.map((id, s) => MapEntry(id, s.toJson()))),
    );
  }

  /// Endpoints en el orden en que conviene probarlos en este arranque.
  Future<List<VpnEndpoint>> orderedEndpoints() async {
    final stats = await load();
    final now = DateTime.now();
    final ordered = order(defaultOrder(nodes), stats, now: now);
    debugPrint(
      '🔒 [VPN] Ranking: ${ordered.take(6).map((e) {
        final s = stats[e.id]?.decayed(now);
        return '$e=${(s?.score ?? neutralScore).toStringAsFixed(2)}';
      }).join(' > ')}',
    );
    return ordered;
  }

  /// Orden de fábrica: una vuelta por servidor, y cada servidor de un mismo
  /// proveedor arranca por otro puerto (el primero por el 1.º, el segundo
  /// por el 2.º…). Así, sin historial, los primeros intentos ya prueban
  /// servidores y puertos distintos en vez de insistir con un puerto que
  /// quizá la red bloquea.
  @visibleForTesting
  static List<VpnEndpoint> defaultOrder(List<VpnNode> nodes) {
    final lists = <List<VpnEndpoint>>[];
    final seen = <VpnProvider, int>{};
    for (final node in nodes) {
      final eps = node.endpoints;
      if (eps.isEmpty) continue;
      final nth = seen[node.provider] ?? 0;
      seen[node.provider] = nth + 1;
      final shift = nth % eps.length;
      lists.add([...eps.sublist(shift), ...eps.sublist(0, shift)]);
    }
    final rounds = lists.fold(0, (n, l) => max(n, l.length));
    return [
      for (var round = 0; round < rounds; round++)
        for (final l in lists)
          if (round < l.length) l[round],
    ];
  }

  /// Ordena [endpoints] (que vienen en el orden de fábrica) según [stats].
  @visibleForTesting
  static List<VpnEndpoint> order(
    List<VpnEndpoint> endpoints,
    Map<String, VpnEndpointStats> stats, {
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final s = {
      for (final e in endpoints)
        e.id: (stats[e.id] ?? const VpnEndpointStats()).decayed(at),
    };
    final index = {for (var i = 0; i < endpoints.length; i++) endpoints[i]: i};
    final ordered = [...endpoints]
      ..sort((a, b) {
        final sa = s[a.id]!, sb = s[b.id]!;
        if ((sa.score - sb.score).abs() >= _tie) {
          return sb.score.compareTo(sa.score);
        }
        final speed = (sa.avgMs ?? double.infinity).compareTo(
          sb.avgMs ?? double.infinity,
        );
        // Sort de Dart no es estable: el índice de fábrica desempata.
        return speed != 0 ? speed : index[a]!.compareTo(index[b]!);
      });

    // El último que anduvo, adelante (si no viene fallando).
    VpnEndpoint? sticky;
    DateTime? stickyWin;
    for (final e in endpoints) {
      final st = s[e.id]!;
      final win = st.lastWin;
      if (win == null || st.failStreak >= maxFailStreak) continue;
      if (stickyWin == null || win.isAfter(stickyWin)) {
        sticky = e;
        stickyWin = win;
      }
    }
    if (sticky != null) {
      ordered
        ..remove(sticky)
        ..insert(0, sticky);
    }
    return ordered;
  }

  /// Anota los resultados de un arranque.
  Future<void> recordAll(List<VpnAttemptResult> results) async {
    if (results.isEmpty) return;
    final stats = await load();
    final now = DateTime.now();
    for (final r in results) {
      final id = r.endpoint.id;
      stats[id] = update(
        stats[id] ?? const VpnEndpointStats(),
        attempt: r.attempt,
        elapsed: r.elapsed,
        now: now,
      );
      final verb = switch (r.attempt) {
        VpnAttempt.success => 'sirvió',
        VpnAttempt.failure => 'falló',
        VpnAttempt.transient => 'sin conclusión',
      };
      debugPrint(
        '🔒 [VPN] $id $verb → tasa ${stats[id]!.score.toStringAsFixed(2)}',
      );
    }
    await _save(stats);
  }

  @visibleForTesting
  static VpnEndpointStats update(
    VpnEndpointStats old, {
    required VpnAttempt attempt,
    Duration? elapsed,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final d = old.decayed(at);
    final ms = elapsed?.inMilliseconds.toDouble();
    switch (attempt) {
      case VpnAttempt.success:
        return VpnEndpointStats(
          wins: d.wins + 1,
          tries: d.tries + 1,
          avgMs: ms == null
              ? d.avgMs
              : (d.avgMs == null ? ms : 0.7 * d.avgMs! + 0.3 * ms),
          lastUsed: at,
          lastWin: at,
        );
      case VpnAttempt.failure:
        return VpnEndpointStats(
          wins: d.wins,
          tries: d.tries + 1,
          avgMs: d.avgMs,
          lastUsed: at,
          lastWin: d.lastWin,
          failStreak: d.failStreak + 1,
        );
      case VpnAttempt.transient:
        return VpnEndpointStats(
          wins: d.wins,
          tries: d.tries,
          avgMs: d.avgMs,
          lastUsed: at,
          lastWin: d.lastWin,
          failStreak: d.failStreak,
        );
    }
  }
}
