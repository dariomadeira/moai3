import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/config/constants.dart';

void main() {
  test('hosts críticos y sus subdominios usan TLS estricto', () {
    expect(isStrictSslHost('klnk.supabase.co'), isTrue);
    expect(isStrictSslHost('api.github.com'), isTrue);
    expect(isStrictSslHost('raw.githubusercontent.com'), isTrue);
    expect(isStrictSslHost('API.WeatherAPI.com'), isTrue);
  });

  test('un dominio que solo contiene el nombre no es estricto', () {
    expect(isStrictSslHost('github.com.evil.net'), isFalse);
    expect(isStrictSslHost('notgithub.com'), isFalse);
    expect(isStrictSslHost('cdn-py.cvattv.com.ar'), isFalse);
  });
}
