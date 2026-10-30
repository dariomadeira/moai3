import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/movie_metadata_service.dart';

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, String> _headers = {};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = value.toString();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  final String body;
  @override
  final int statusCode;

  _FakeHttpClientResponse(this.body, {this.statusCode = 200});

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  final String responseBody;
  final int responseStatus;
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  _FakeHttpClientRequest(this.responseBody, {this.responseStatus = 200});

  @override
  Future<HttpClientResponse> close() async {
    return _FakeHttpClientResponse(responseBody, statusCode: responseStatus);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClient implements HttpClient {
  final String responseBody;
  final int responseStatus;
  Uri? lastRequestedUri;

  _FakeHttpClient(this.responseBody, {this.responseStatus = 200});

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    lastRequestedUri = url;
    return _FakeHttpClientRequest(responseBody, responseStatus: responseStatus);
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CountingHttpClient extends _FakeHttpClient {
  int requests = 0;

  _CountingHttpClient(super.responseBody);

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    requests++;
    return super.getUrl(url);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MovieMetadataService.resetForTest();
  });

  test('si la película ya tiene un año de estreno formateado, lo devuelve de inmediato', () async {
    final movie = MovieItem(
      contentId: '100',
      name: 'Interestelar',
      year: '2014',
    );

    final year = await MovieMetadataService.instance.resolveYear(movie);
    expect(year, '2014');
  });

  test('si está en SharedPreferences, lo devuelve sin consultar TMDb', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tmdb_year_15406', '1976');

    final movie = MovieItem(
      contentId: '15406',
      name: 'Rocky',
    );

    final year = await MovieMetadataService.instance.resolveYear(movie);
    expect(year, '1976');
  });

  test('consulta TMDb, encuentra Rocky 1976 y lo guarda en caché persistente', () async {
    dotenv.loadFromString(envString: 'TMDB_API_KEY=test_tmdb_token_123');

    final tmdbResponseBody = jsonEncode({
      'page': 1,
      'results': [
        {
          'id': 1366,
          'title': 'Rocky',
          'original_title': 'Rocky',
          'release_date': '1976-11-21',
          'popularity': 45.5,
          'vote_count': 7500,
        },
        {
          'id': 9999,
          'title': 'Rocky II',
          'original_title': 'Rocky II',
          'release_date': '1979-06-15',
          'popularity': 20.1,
          'vote_count': 3000,
        },
      ],
    });

    final fakeClient = _FakeHttpClient(tmdbResponseBody);

    final movie = MovieItem(
      contentId: '15406',
      name: 'Rocky',
      alias: 'Rocky',
      director: 'John G. Avildsen',
    );

    final year = await MovieMetadataService.instance.resolveYear(
      movie,
      customClient: fakeClient,
    );

    expect(year, '1976');
    expect(fakeClient.lastRequestedUri?.queryParameters['query'], 'Rocky');

    // Comprobar que quedó guardado en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tmdb_year_15406'), '1976');

    // La segunda consulta usa la caché (pasando un fakeClient que fallaría)
    final failingClient = _FakeHttpClient('', responseStatus: 500);
    final cachedYear = await MovieMetadataService.instance.resolveYear(
      movie,
      customClient: failingClient,
    );
    expect(cachedYear, '1976');
  });

  test('un error de TMDb no se guarda: la próxima vez vuelve a consultar', () async {
    dotenv.loadFromString(envString: 'TMDB_API_KEY=test_tmdb_token_123');
    final movie = MovieItem(contentId: '15406', name: 'Rocky');

    final failed = await MovieMetadataService.instance.resolveYear(
      movie,
      customClient: _FakeHttpClient('', responseStatus: 500),
    );
    expect(failed, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tmdb_year_15406'), isNull);

    final okClient = _FakeHttpClient(jsonEncode({
      'results': [
        {'title': 'Rocky', 'original_title': 'Rocky', 'release_date': '1976-11-21'},
      ],
    }));
    final year = await MovieMetadataService.instance.resolveYear(
      movie,
      customClient: okClient,
    );
    expect(year, '1976');
    expect(okClient.lastRequestedUri, isNotNull);
  });

  test('si TMDb contestó sin coincidencias, lo recuerda y no vuelve a consultar', () async {
    dotenv.loadFromString(envString: 'TMDB_API_KEY=test_tmdb_token_123');
    final movie = MovieItem(contentId: 'x1', name: 'Película inexistente');

    final first = await MovieMetadataService.instance.resolveYear(
      movie,
      customClient: _FakeHttpClient(jsonEncode({'results': []})),
    );
    expect(first, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tmdb_year_x1'), '-');

    // Sin caché en memoria: lee lo guardado y no sale a la red.
    MovieMetadataService.resetForTest();
    final untouched = _FakeHttpClient('', responseStatus: 500);
    final second = await MovieMetadataService.instance.resolveYear(
      movie,
      customClient: untouched,
    );
    expect(second, isNull);
    expect(untouched.lastRequestedUri, isNull);
  });

  test('un vacío guardado por la versión anterior se ignora y se consulta', () async {
    dotenv.loadFromString(envString: 'TMDB_API_KEY=test_tmdb_token_123');
    SharedPreferences.setMockInitialValues({'tmdb_year_15406': ''});
    final client = _FakeHttpClient(jsonEncode({
      'results': [
        {'title': 'Rocky', 'original_title': 'Rocky', 'release_date': '1976-11-21'},
      ],
    }));

    final year = await MovieMetadataService.instance.resolveYear(
      MovieItem(contentId: '15406', name: 'Rocky'),
      customClient: client,
    );
    expect(year, '1976');
  });

  test('dos pedidos seguidos de la misma película hacen una sola consulta', () async {
    dotenv.loadFromString(envString: 'TMDB_API_KEY=test_tmdb_token_123');
    final client = _CountingHttpClient(jsonEncode({
      'results': [
        {'title': 'Rocky', 'original_title': 'Rocky', 'release_date': '1976-11-21'},
      ],
    }));
    final movie = MovieItem(contentId: '15406', name: 'Rocky');

    final results = await Future.wait([
      MovieMetadataService.instance.resolveYear(movie, customClient: client),
      MovieMetadataService.instance.resolveYear(movie, customClient: client),
    ]);
    expect(results, ['1976', '1976']);
    expect(client.requests, 1);
  });

  test('desempata por coincidencia exacta de título y popularidad', () async {
    dotenv.loadFromString(envString: 'TMDB_API_KEY=test_tmdb_token_123');

    final tmdbResponseBody = jsonEncode({
      'page': 1,
      'results': [
        {
          'id': 200,
          'title': 'Rocky (Versión Alternativa)',
          'original_title': 'Rocky Remake',
          'release_date': '2010-05-10',
          'popularity': 5.0,
        },
        {
          'id': 100,
          'title': 'Rocky',
          'original_title': 'Rocky',
          'release_date': '1976-11-21',
          'popularity': 45.0,
        },
      ],
    });

    final fakeClient = _FakeHttpClient(tmdbResponseBody);

    final movie = MovieItem(
      contentId: 'rocky_id',
      name: 'Rocky',
    );

    final year = await MovieMetadataService.instance.resolveYear(
      movie,
      customClient: fakeClient,
    );

    expect(year, '1976');
  });
}
