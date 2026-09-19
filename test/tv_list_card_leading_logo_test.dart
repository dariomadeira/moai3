import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/services/moai_image_cache_manager.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_logo.dart';

void main() {
  test('MoaiImageCacheManager usa versión 2 sin distorsión', () {
    expect(MoaiImageCacheManager.key, equals('moai_channel_logos_v2'));
  });

  testWidgets('TvListCardLeadingLogo renderiza placeholder cuando la URL está vacía', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TvListCardLeadingLogo(
            logoUrl: '',
            width: 54,
            height: 36,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.tv_rounded), findsOneWidget);
  });

  testWidgets('TvListCardLeadingLogo usa BoxFit.contain y alignment center en CachedNetworkImage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TvListCardLeadingLogo(
            logoUrl: 'https://example.com/logo.png',
            width: 54,
            height: 36,
          ),
        ),
      ),
    );

    final cachedImageFinder = find.byType(CachedNetworkImage);
    expect(cachedImageFinder, findsOneWidget);

    final cachedImage = tester.widget<CachedNetworkImage>(cachedImageFinder);
    expect(cachedImage.fit, equals(BoxFit.contain));
    expect(cachedImage.alignment, equals(Alignment.center));
    expect(cachedImage.memCacheWidth, isNull);
    expect(cachedImage.maxWidthDiskCache, isNull);
    expect(cachedImage.maxHeightDiskCache, isNull);
    expect(cachedImage.memCacheHeight, equals(120));
  });

  testWidgets('TvListCardLeadingLogo usa BoxFit.contain en SVG', (tester) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TvListCardLeadingLogo(
              logoUrl: 'https://example.com/logo.svg',
              width: 54,
              height: 36,
            ),
          ),
        ),
      );

      final svgFinder = find.byType(SvgPicture);
      expect(svgFinder, findsOneWidget);

      final svgWidget = tester.widget<SvgPicture>(svgFinder);
      expect(svgWidget.fit, equals(BoxFit.contain));
      expect(svgWidget.alignment, equals(Alignment.center));
    }, createHttpClient: (_) => _createMockSvgClient());
  });

  testWidgets('TvListCardLeadingLogo usa BoxFit.contain en Image.asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TvListCardLeadingLogo(
            logoUrl: 'assets/channels/telefe.png',
            width: 54,
            height: 36,
          ),
        ),
      ),
    );

    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);

    final imageWidget = tester.widget<Image>(imageFinder);
    expect(imageWidget.fit, equals(BoxFit.contain));
    expect(imageWidget.alignment, equals(Alignment.center));
  });
}

HttpClient _createMockSvgClient() => _MockHttpClient();

class _MockHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _MockHttpClientRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _MockHttpClientRequest();

  @override
  void close({bool force = false}) {}
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = 0;

  @override
  bool persistentConnection = false;

  @override
  bool bufferOutput = false;

  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  void add(List<int> data) {}

  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();
}

class _MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  List<String>? operator [](String name) => null;

  @override
  String? value(String name) => null;
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _svgBytes.length;

  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get persistentConnection => false;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  static final List<int> _svgBytes =
      utf8.encode('<svg viewBox="0 0 10 10"><rect width="10" height="10"/></svg>');

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(_svgBytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
