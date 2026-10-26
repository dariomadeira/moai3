import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moai3/services/vpn_service.dart';

void main() {
  final vpn = VpnService.instance;

  /// Corre [body] con un cliente HTTP falso: [cloudflare] e [ipApi] dicen
  /// qué contesta cada servicio (null: no contesta).
  Future<T> withNetwork<T>(
    Future<T> Function() body, {
    String? cloudflare,
    String? ipApi,
    void Function()? onRequest,
  }) => http.runWithClient(
    body,
    () => MockClient((request) async {
      onRequest?.call();
      final host = request.url.host;
      final answer = host.contains('cloudflare')
          ? (cloudflare == null ? null : 'ip=1.2.3.4\nloc=$cloudflare\n')
          : (ipApi == null
                ? null
                : '{"countryCode":"$ipApi","query":"1.2.3.4"}');
      if (answer == null) throw const SocketExceptionLike();
      return http.Response(answer, 200);
    }),
  );

  test('alcanza con que conteste uno de los dos', () async {
    final result = await withNetwork(
      () => vpn.checkExit(country: 'MX'),
      cloudflare: 'MX',
    );
    expect(result, VpnExitCheck.matches);
  });

  test('otro país se informa como otro país', () async {
    final result = await withNetwork(
      () => vpn.checkExit(country: 'MX'),
      ipApi: 'US',
    );
    expect(result, VpnExitCheck.otherCountry);
  });

  test('si nadie contesta reintenta y avisa que no hubo respuesta', () async {
    var requests = 0;
    final result = await withNetwork(
      () => vpn.checkExit(country: 'MX'),
      onRequest: () => requests++,
    );
    expect(result, VpnExitCheck.noAnswer);
    // Tres rondas, las dos consultas en cada una.
    expect(requests, 6);
  });
}

/// Error de red de prueba.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
