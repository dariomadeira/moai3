import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/engine/engine_player_view.dart';
import 'package:moai3/features/movies/movie_player_format.dart';
import 'package:moai3/features/movies/screens/movie_player_screen.dart';
import 'package:moai3/features/movies/series_playlist.dart';
import 'package:moai3/features/movies/widgets/movie_player_osd.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/platform/platform_channels.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/movie_progress_service.dart';
import 'package:moai3/services/movie_recommendations_api.dart';
import 'package:moai3/state/movie_recommendations_provider.dart';
import 'package:moai3/services/movie_watchlist_service.dart';
import 'package:moai3/services/series_watch_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/spanish_translations.dart';

/// Motor nativo simulado: una película de 2 h parada en el minuto 1.
class _FakeEngine {
  final calls = <MethodCall>[];
  final events = StreamController<Object?>.broadcast();
  Duration position = const Duration(minutes: 1);

  List<int> get seeks => [
    for (final c in calls)
      if (c.method == 'seekTo') (c.arguments as Map)['positionMs'] as int,
  ];

  int count(String method) => calls.where((c) => c.method == method).length;

  /// Cada reproductor tiene su número, como en el aparato (los capítulos
  /// abren uno nuevo); los avisos van al último.
  int _handles = 0;
  static const _maxHandles = 4;

  void install(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(PlatformChannels.player, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'create':
          _handles++;
          return {'handle': _handles, 'textureId': _handles};
        case 'getPosition':
          return position.inMilliseconds;
        case 'getDuration':
          return const Duration(hours: 2).inMilliseconds;
        case 'getStatus':
          return {
            'position': position.inMilliseconds,
            'duration': const Duration(hours: 2).inMilliseconds,
            'buffered': position.inMilliseconds,
          };
      }
      return null;
    });
    for (var handle = 1; handle <= _maxHandles; handle++) {
      messenger.setMockStreamHandler(
        PlatformChannels.playerEvents(handle),
        MockStreamHandler.inline(
          onListen: (_, sink) {
            events.stream.where((_) => handle == _handles).listen(sink.success);
          },
        ),
      );
    }
    addTearDown(() {
      messenger.setMockMethodCallHandler(PlatformChannels.player, null);
      for (var handle = 1; handle <= _maxHandles; handle++) {
        messenger.setMockStreamHandler(
          PlatformChannels.playerEvents(handle),
          null,
        );
      }
    });
  }

  /// El video arrancó: primer cuadro y reproduciendo.
  void startPlaying() {
    events.add({'event': 'state', 'value': 'ready'});
    events.add({'event': 'playing', 'value': true});
    events.add({'event': 'firstFrame'});
  }
}

class _RecommendationsApi extends MovieRecommendationsApi {
  final sent = <String>[];

  @override
  Future<List<Map<String, dynamic>>> fetch(List<String> friendIds) async =>
      const [];

  @override
  Future<void> recommend(String deviceId, MovieItem movie) async {
    sent.add(movie.contentId);
  }
}

void main() {
  group('preferredAudioCode', () {
    test('español e inglés se piden siempre', () {
      expect(preferredAudioCode(MovieAudioLanguage.spanish, 'spa,eng'), 'es');
      expect(preferredAudioCode(MovieAudioLanguage.english, 'spa,eng'), 'en');
    });

    test('original: el primero que no es español', () {
      const original = MovieAudioLanguage.original;
      expect(preferredAudioCode(original, 'spa,spa,eng'), 'en');
      expect(preferredAudioCode(original, 'spa,kor'), 'ko');
      // Película en español: sin preferencia, suena la que trae.
      expect(preferredAudioCode(original, 'spa'), isNull);
    });
  });

  group('movieAudioOptions', () {
    test('dos audios del mismo idioma son opciones distintas', () {
      useSpanishTranslations();
      final options = movieAudioOptions('spa,spa,eng');

      expect(options.map((o) => o.code), ['es', 'es', 'en']);
      expect(options.map((o) => o.occurrence), [0, 1, 0]);
      expect(options.map(movieAudioLabel), [
        'Español 1',
        'Español 2',
        'Inglés',
      ]);
    });

    test('con uno solo de cada idioma no se numera', () {
      useSpanishTranslations();
      expect(movieAudioOptions('spa,eng').map(movieAudioLabel), [
        'Español',
        'Inglés',
      ]);
    });
  });

  group('subtítulos', () {
    test('lee la URL aunque `file` venga como texto (como manda la API)', () {
      final sub = VodSubtitleOption.fromJson({
        'language': 'es',
        'file':
            "[{'url': 'http://vpnwqk.k9ijj2.com/public/subs/6e38.srt', "
            "'fileType': 'srt'}]",
      });
      expect(sub.url, 'http://vpnwqk.k9ijj2.com/public/subs/6e38.srt');
      expect(sub.language, 'es');
      expect(sub.mimeType, 'application/x-subrip');
    });

    test('elige según el ajuste; apagado o sin ese idioma, ninguno', () {
      const subs = [
        VodSubtitleOption(name: 'en', language: 'en', url: 'http://x/en.srt'),
        VodSubtitleOption(name: 'es', language: 'es', url: 'http://x/es.srt'),
      ];
      expect(pickSubtitle(MovieSubtitleLanguage.off, subs), isNull);
      expect(
        pickSubtitle(MovieSubtitleLanguage.spanish, subs)?.url,
        'http://x/es.srt',
      );
      expect(
        pickSubtitle(MovieSubtitleLanguage.english, subs)?.url,
        'http://x/en.srt',
      );
      expect(
        pickSubtitle(MovieSubtitleLanguage.english, subs.sublist(1)),
        isNull,
      );
    });
  });

  group('MovieScrub', () {
    const total = Duration(hours: 2);

    test('un toque salta 10 s; mantenida acelera hasta 5 min', () {
      expect(MovieScrub.stepFor(0), const Duration(seconds: 10));
      expect(MovieScrub.stepFor(8), const Duration(seconds: 30));
      expect(MovieScrub.stepFor(20), const Duration(minutes: 1));
      expect(MovieScrub.stepFor(40), const Duration(minutes: 5));
    });

    test('no se sale de la película', () {
      expect(
        MovieScrub.target(
          from: const Duration(seconds: 5),
          forward: false,
          repeats: 0,
          total: total,
        ),
        Duration.zero,
      );
      expect(
        MovieScrub.target(
          from: total - const Duration(seconds: 3),
          forward: true,
          repeats: 50,
          total: total,
        ),
        total - const Duration(seconds: 1),
      );
    });
  });

  group('formato', () {
    test('tiempos y diferencias', () {
      expect(formatPlayerTime(const Duration(seconds: 309)), '5:09');
      expect(
        formatPlayerTime(const Duration(hours: 1, minutes: 5, seconds: 9)),
        '1:05:09',
      );
      expect(formatPlayerDelta(const Duration(seconds: 150)), '+2:30');
      expect(formatPlayerDelta(const Duration(seconds: -40)), '−0:40');
    });

    test('audio y calidad legibles', () {
      useSpanishTranslations();
      expect(audioLanguageLabel('esp'), 'Español');
      expect(audioLanguageLabel('Latino'), 'Latino');
      expect(audioLanguageLabel('lat'), 'Latino');
      expect(audioLanguageLabel('eng'), 'Inglés');
      expect(audioLanguageLabel('fra'), 'Francés');
      expect(audioLanguageLabel('xyz'), 'XYZ');
      // Como los manda ExoPlayer, y con el nombre de la pista.
      expect(audioLanguageLabel('es'), 'Español');
      expect(audioLanguageLabel('es-419'), 'Latino');
      expect(audioLanguageLabel('es', trackLabel: 'Latino'), 'Latino');
      expect(audioLanguageLabel('ja'), 'Japonés');
      // La lista de la API: el primero.
      expect(audioLanguageLabel('spa,spa,eng'), 'Español');
      expect(qualityLabel('1080P HD'), '1080p');
      expect(qualityLabel('4K UHD'), '4K');
      expect(qualityLabel('Auto'), 'Auto');
    });
  });

  group('MoviePlayerScreen', () {
    late _FakeEngine engine;

    /// [prefs]: ajustes guardados (idioma del audio, subtítulos…).
    Future<void> pumpPlayer(
      WidgetTester tester, {
      Map<String, Object> prefs = const {},
      String audioInfo = 'esp',
      MovieRecommendationsProvider? recommendations,
    }) async {
      useSpanishTranslations();
      SharedPreferences.setMockInitialValues(prefs);
      final settings = TvSettingsProvider(await AppPreferences.init());
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      engine = _FakeEngine()..install(tester);
      recommendations?.setFriends(
        deviceId: 'yo',
        friends: const {'ana': 'Ana'},
      );
      await recommendations?.ensureLoaded();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            if (recommendations != null)
              ChangeNotifierProvider.value(value: recommendations),
          ],
          child: MaterialApp(
            home: MoviePlayerScreen(
              movie: MovieItem(contentId: 'p1', name: 'Tenzing'),
              stream: ResolvedPlayStream(
                streamUrl: 'https://example.com/v.m3u8',
                quality: '1080P HD',
                audioInfo: audioInfo,
                subtitles: const [
                  VodSubtitleOption(
                    name: 'en',
                    language: 'en',
                    url: 'http://subs.example.com/en.srt',
                  ),
                  VodSubtitleOption(
                    name: 'es',
                    language: 'es',
                    url: 'http://subs.example.com/es.srt',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      engine.startPlaying();
      // Una vuelta del sondeo de posición para conocer la duración.
      await tester.pump(const Duration(milliseconds: 700));
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    }

    testWidgets('pide el audio del ajuste y el chip muestra el que suena', (
      tester,
    ) async {
      await pumpPlayer(tester);

      // Sin ajuste guardado: español.
      final setMedia = engine.calls.firstWhere((c) => c.method == 'setMedia');
      expect((setMedia.arguments as Map)['preferredAudioLanguage'], 'es');

      // ExoPlayer informa sus pistas: el chip sigue a la que suena.
      engine.events.add({
        'event': 'audioTracks',
        'value': [
          {'language': 'es', 'label': null, 'selected': false},
          {'language': 'en', 'label': null, 'selected': true},
        ],
      });
      await tester.pump();
      expect(find.text('Inglés'), findsOneWidget);
      expect(find.text('Español'), findsNothing);
      await finish(tester);
    });

    group('recomendar al final', () {
      const prompt = '¿Se la recomendás a tus amigos?';
      late _RecommendationsApi api;

      Future<void> reachEnd(WidgetTester tester) async {
        api = _RecommendationsApi();
        await pumpPlayer(
          tester,
          recommendations: MovieRecommendationsProvider(api: api),
        );
        engine.position = const Duration(hours: 1, minutes: 56);
        await tester.pump(const Duration(milliseconds: 700));
      }

      testWidgets('pregunta en los últimos minutos, una sola vez', (
        tester,
      ) async {
        await reachEnd(tester);
        expect(find.text(prompt), findsOneWidget);

        await tester.pump(const Duration(seconds: 21));
        expect(find.text(prompt), findsNothing);

        await tester.pump(const Duration(seconds: 2));
        expect(find.text(prompt), findsNothing);
        await finish(tester);
      });

      testWidgets('un OK distraído cancela y no pausa', (tester) async {
        await reachEnd(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(find.text(prompt), findsNothing);
        expect(api.sent, isEmpty);
        expect(engine.count('pause'), 0);
        await finish(tester);
      });

      testWidgets('pulgar arriba recomienda la película', (tester) async {
        await reachEnd(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump();

        expect(api.sent, ['p1']);
        await tester.pump(const Duration(seconds: 5));
        await finish(tester);
      });

      testWidgets('si se llegó saltando no pregunta', (tester) async {
        await pumpPlayer(
          tester,
          recommendations: MovieRecommendationsProvider(
            api: _RecommendationsApi(),
          ),
        );
        for (var i = 0; i < 60; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        }
        await tester.pump();
        expect(find.text(prompt), findsNothing);
        await finish(tester);
      });
    });

    testWidgets('arranca con el audio recordado de esa película', (
      tester,
    ) async {
      await pumpPlayer(
        tester,
        audioInfo: 'spa,spa,eng',
        prefs: {'movie_audio_choices': '{"p1":"es:1"}'},
      );

      final args =
          engine.calls.firstWhere((c) => c.method == 'setMedia').arguments
              as Map;
      expect(args['preferredAudioLanguage'], 'es');
      expect(args['preferredAudioOccurrence'], 1);
      expect(find.text('Español 2'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('elegir el otro español recarga con esa pista y la recuerda', (
      tester,
    ) async {
      await pumpPlayer(tester, audioInfo: 'spa,spa,eng');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      final setMedias = engine.calls.where((c) => c.method == 'setMedia');
      expect(setMedias, hasLength(2));
      expect((setMedias.last.arguments as Map)['preferredAudioOccurrence'], 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('movie_audio_choices'), '{"p1":"es:1"}');
      await finish(tester);
    });

    testWidgets('subtítulos apagados por defecto: no se cargan', (
      tester,
    ) async {
      await pumpPlayer(tester);
      final setMedia = engine.calls.firstWhere((c) => c.method == 'setMedia');
      expect((setMedia.arguments as Map)['subtitleUrl'], isNull);
      await finish(tester);
    });

    testWidgets('con subtítulos en español carga ese y muestra el texto', (
      tester,
    ) async {
      await pumpPlayer(tester, prefs: {'movie_subtitle_language': 'spanish'});
      final args =
          engine.calls.firstWhere((c) => c.method == 'setMedia').arguments
              as Map;
      expect(args['subtitleUrl'], 'http://subs.example.com/es.srt');
      expect(args['subtitleMimeType'], 'application/x-subrip');
      expect(args['subtitleLanguage'], 'es');

      engine.events.add({'event': 'cues', 'value': '¿Estás bien, Yeshi?'});
      await tester.pump();
      expect(find.text('¿Estás bien, Yeshi?'), findsOneWidget);

      // El canal simulado entrega el evento un cuadro después.
      engine.events.add({'event': 'cues', 'value': ''});
      await tester.pump();
      await tester.pump();
      expect(find.text('¿Estás bien, Yeshi?'), findsNothing);
      await finish(tester);
    });

    /// La interfaz (franja superior y panel) está visible.
    bool osdVisible(WidgetTester tester) =>
        tester
            .widget<AnimatedOpacity>(
              find
                  .ancestor(
                    of: find.text('Tenzing'),
                    matching: find.byType(AnimatedOpacity),
                  )
                  .first,
            )
            .opacity ==
        1.0;

    testWidgets('si a los 4 s está cargando, se esconde apenas reproduce', (
      tester,
    ) async {
      await pumpPlayer(tester);
      // Se pone a cargar (p. ej. tras un salto) y sigue así más de 4 s.
      engine.events.add({'event': 'state', 'value': 'buffering'});
      engine.events.add({'event': 'playing', 'value': false});
      await tester.pump(const Duration(seconds: 5));
      expect(osdVisible(tester), isTrue);

      engine.events.add({'event': 'state', 'value': 'ready'});
      engine.events.add({'event': 'playing', 'value': true});
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      expect(osdVisible(tester), isFalse);
      await finish(tester);
    });

    testWidgets('en pausa la interfaz queda visible', (tester) async {
      await pumpPlayer(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(seconds: 6));
      expect(osdVisible(tester), isTrue);
      await finish(tester);
    });

    testWidgets('atrás esconde la interfaz aunque esté cargando', (
      tester,
    ) async {
      await pumpPlayer(tester);
      engine.events.add({'event': 'state', 'value': 'buffering'});
      await tester.pump();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      expect(osdVisible(tester), isFalse);
      expect(find.byType(MoviePlayerScreen), findsOneWidget);
      await finish(tester);
    });

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }

    Map<dynamic, dynamic> lastSetMedia() =>
        engine.calls.lastWhere((c) => c.method == 'setMedia').arguments as Map;

    testWidgets('el subtítulo se cambia en la película y retoma ahí', (
      tester,
    ) async {
      await pumpPlayer(tester);

      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.text('Apagados'), findsOneWidget);
      expect(find.text('Inglés'), findsOneWidget);

      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.enter);

      expect(engine.count('setMedia'), 2);
      expect(lastSetMedia()['subtitleUrl'], 'http://subs.example.com/es.srt');
      expect(find.text('Apagados'), findsNothing);
      expect(
        lastSetMedia()['startPositionMs'],
        const Duration(minutes: 1).inMilliseconds,
      );
      engine.startPlaying();
      await tester.pump();
      expect(engine.seeks, isEmpty);
      await finish(tester);
    });

    testWidgets('elegir lo que ya está no recarga', (tester) async {
      await pumpPlayer(tester);
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.enter);
      await press(tester, LogicalKeyboardKey.enter);
      expect(engine.count('setMedia'), 1);
      await finish(tester);
    });

    testWidgets('el audio se cambia en la película sin tocar el ajuste', (
      tester,
    ) async {
      await pumpPlayer(tester, audioInfo: 'spa,spa,eng');

      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.enter);
      // Español 1, Español 2, Inglés.
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.enter);

      expect(lastSetMedia()['preferredAudioLanguage'], 'en');
      final context = tester.element(find.byType(MoviePlayerScreen));
      expect(
        context.read<TvSettingsProvider>().movieAudioLanguage,
        MovieAudioLanguage.spanish,
      );
      await finish(tester);
    });

    testWidgets('el tamaño se aplica al instante y queda guardado', (
      tester,
    ) async {
      await pumpPlayer(tester, prefs: {'movie_subtitle_language': 'spanish'});
      engine.events.add({'event': 'cues', 'value': 'Hola'});
      await tester.pump();
      double size() => tester.widget<Text>(find.text('Hola')).style!.fontSize!;
      expect(size(), MovieSubtitleSize.medium.fontSize);

      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.enter);
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.enter);
      await tester.pump();

      expect(size(), MovieSubtitleSize.large.fontSize);
      expect(engine.count('setMedia'), 1);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'movie_subtitle_size',
        ),
        'large',
      );
      await finish(tester);
    });

    testWidgets('atrás sale del menú y de las píldoras sin irse', (
      tester,
    ) async {
      await pumpPlayer(tester);
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.enter);

      await press(tester, LogicalKeyboardKey.escape);
      expect(find.text('Apagados'), findsNothing);
      await press(tester, LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(MoviePlayerScreen), findsOneWidget);
      expect(osdVisible(tester), isTrue);

      // Volvió a la barra: las flechas buscan otra vez.
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(find.text('+0:10'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('chips legibles y sin el de subtítulos', (tester) async {
      await pumpPlayer(tester);

      expect(find.text('Tenzing'), findsOneWidget);
      expect(find.text('1080p'), findsOneWidget);
      expect(find.text('Español'), findsOneWidget);
      expect(find.text('esp'), findsNothing);
      expect(find.text('1:00'), findsOneWidget);
      expect(find.text('−1:59:00'), findsOneWidget);

      // Detrás del video, negro: es lo que se ve en las franjas de una
      // película más ancha que la pantalla.
      final background = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(EnginePlayerView),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(background.color, Colors.black);
      await finish(tester);
    });

    testWidgets('→ muestra el destino y salta una sola vez al soltar', (
      tester,
    ) async {
      await pumpPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(find.text('+0:20'), findsOneWidget);
      expect(engine.seeks, isEmpty);

      await tester.pump(const Duration(seconds: 1));
      expect(engine.seeks, [
        const Duration(minutes: 1, seconds: 20).inMilliseconds,
      ]);
      expect(find.text('+0:20'), findsNothing);
      await finish(tester);
    });

    testWidgets('mantener → acelera', (tester) async {
      await pumpPlayer(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      for (var i = 0; i < 25; i++) {
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(seconds: 1));

      // Toque + 7 repeticiones de 10 s, 12 de 30 s y 6 de 1 min: +13:20
      // desde el minuto 1.
      expect(engine.seeks, [
        const Duration(minutes: 14, seconds: 20).inMilliseconds,
      ]);
      await finish(tester);
    });

    testWidgets('OK durante la búsqueda salta ya y no pausa', (tester) async {
      await pumpPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(engine.seeks, [const Duration(seconds: 50).inMilliseconds]);
      expect(engine.count('pause'), 0);
      await finish(tester);
    });

    testWidgets('atrás durante la búsqueda la cancela sin saltar', (
      tester,
    ) async {
      await pumpPlayer(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(seconds: 1));

      expect(engine.seeks, isEmpty);
      expect(find.byType(MoviePlayerScreen), findsOneWidget);
      await finish(tester);
    });

    testWidgets('si el video falla, avisa y OK reintenta desde ahí', (
      tester,
    ) async {
      await pumpPlayer(tester);
      expect(engine.count('setMedia'), 1);

      engine.events.add({
        'event': 'error',
        'value': {'code': 2001, 'message': 'red'},
      });
      await tester.pump();
      expect(find.text('No se pudo reproducir'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text('No se pudo reproducir'), findsNothing);
      expect(engine.count('setMedia'), 2);

      // El video arranca directo en el minuto 1, sin pasar por el principio
      // (el proxy de Titan daría 404).
      final reload = engine.calls.lastWhere((c) => c.method == 'setMedia');
      expect(
        (reload.arguments as Map)['startPositionMs'],
        const Duration(minutes: 1).inMilliseconds,
      );
      engine.startPlaying();
      await tester.pump();
      expect(engine.seeks, isEmpty);
      await finish(tester);
    });

    /// Abre el reproductor desde una pantalla anterior (como el detalle), para
    /// poder ver que vuelve a ella.
    Future<void> pushPlayer(
      WidgetTester tester, {
      int? initialPositionSeconds,
    }) async {
      useSpanishTranslations();
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      engine = _FakeEngine()..install(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MoviePlayerScreen(
                      movie: MovieItem(contentId: 'p1', name: 'Tenzing'),
                      stream: const ResolvedPlayStream(
                        streamUrl: 'https://example.com/v.m3u8',
                        quality: '1080P HD',
                        audioInfo: 'esp',
                      ),
                      initialPositionSeconds: initialPositionSeconds,
                    ),
                  ),
                ),
                child: const Text('detalle'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('detalle'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('al terminar: queda vista, sale de Interesantes y vuelve', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      MovieWatchlistService.instance.resetForTest();
      await MovieWatchlistService.instance.toggle(
        MovieItem(contentId: 'p1', name: 'Tenzing'),
      );
      await pushPlayer(tester);
      engine.startPlaying();
      await tester.pump(const Duration(milliseconds: 700));

      engine.events.add({'event': 'state', 'value': 'ended'});
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(MoviePlayerScreen), findsNothing);
      expect(find.text('detalle'), findsOneWidget);
      expect(
        (await MovieProgressService.getProgress('p1'))?.isCompleted,
        isTrue,
      );
      expect(MovieWatchlistService.instance.contains('p1'), isFalse);
    });

    group('atrás en el TV (tecla + pop del sistema)', () {
      /// Lo que manda Android al apretar atrás: la tecla y, además, el pop
      /// del sistema.
      Future<void> back(WidgetTester tester, {bool key = true}) async {
        if (key) {
          await tester.sendKeyEvent(
            LogicalKeyboardKey.goBack,
            platform: 'web',
            physicalKey: PhysicalKeyboardKey.browserBack,
          );
        }
        await tester.binding.handlePopRoute();
        await tester.pump();
      }

      testWidgets('cierra sólo el reproductor, no también el detalle', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        await pushPlayer(tester);
        engine.startPlaying();
        await tester.pump(const Duration(milliseconds: 700));
        // La primera esconde la interfaz (sin cerrar nada).
        await back(tester);
        expect(find.byType(MoviePlayerScreen), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        // La segunda cierra el reproductor y queda el detalle.
        await back(tester);
        await tester.pumpAndSettle();
        expect(find.byType(MoviePlayerScreen), findsNothing);
        expect(find.text('detalle'), findsOneWidget);
      });

      testWidgets('el pop del sistema solo hace lo mismo que la tecla', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        await pushPlayer(tester);
        engine.startPlaying();
        await tester.pump(const Duration(milliseconds: 700));
        await back(tester, key: false);
        expect(find.byType(MoviePlayerScreen), findsOneWidget);
        await back(tester, key: false);
        await tester.pumpAndSettle();
        expect(find.byType(MoviePlayerScreen), findsNothing);
        expect(find.text('detalle'), findsOneWidget);
      });
    });

    group('capítulos de una serie', () {
      SeriesPlaylist playlist({required int episodes, bool failNext = false}) =>
          SeriesPlaylist(
            seasons: const [SeriesSeason(contentId: 's1', number: 1)],
            details: {
              's1': SeriesSeasonDetail(
                info: MovieItem(contentId: 's1', name: 'Dark T1'),
                seasons: const [],
                episodes: [
                  for (var n = 1; n <= episodes; n++)
                    SeriesEpisode(contentId: 'e$n', number: n),
                ],
              ),
            },
            startSeasonId: 's1',
            startEpisodeIndex: 0,
            resolveStream: (_, _, _) async => failNext
                ? null
                : const ResolvedPlayStream(
                    streamUrl: 'https://example.com/v2.m3u8',
                    quality: '1080P HD',
                    audioInfo: 'esp',
                  ),
          );

      Future<void> pushEpisode(WidgetTester tester, SeriesPlaylist p) async {
        SharedPreferences.setMockInitialValues({});
        useSpanishTranslations();
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());
        engine = _FakeEngine()..install(tester);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MoviePlayerScreen(
                        movie: p.item,
                        stream: const ResolvedPlayStream(
                          streamUrl: 'https://example.com/v.m3u8',
                          quality: '1080P HD',
                          audioInfo: 'esp',
                        ),
                        series: p,
                      ),
                    ),
                  ),
                  child: const Text('detalle'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('detalle'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        engine.startPlaying();
        await tester.pump(const Duration(milliseconds: 700));
      }

      Future<void> end(WidgetTester tester) async {
        engine.events.add({'event': 'state', 'value': 'ended'});
        await tester.pump();
        await tester.pump();
      }

      testWidgets('al terminar avisa y pasa al siguiente sin preguntar', (
        tester,
      ) async {
        final p = playlist(episodes: 2);
        await pushEpisode(tester, p);
        expect(find.text('Dark · T1 · Capítulo 1'), findsOneWidget);

        await end(tester);
        expect(find.text('Siguiente: Capítulo 2'), findsOneWidget);
        // El nuevo arranca cargando (la ruedita no para: sin pumpAndSettle).
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(MoviePlayerScreen), findsOneWidget);
        expect(find.text('Dark · T1 · Capítulo 2'), findsOneWidget);
        // La serie sigue: el reproductor nuevo la tiene.
        var closed = false;
        unawaited(p.done.then((_) => closed = true));
        await tester.pump();
        expect(closed, isFalse);
        // El primero quedó visto.
        expect((await SeriesWatchService.season('s1')).watched, contains('e1'));
        // No es una película: nada en "Seguir viendo" ni recomendaciones.
        expect(await MovieProgressService.getProgress('e1'), isNull);

        // El último vuelve al detalle.
        engine.startPlaying();
        await tester.pump(const Duration(milliseconds: 700));
        await end(tester);
        await tester.pumpAndSettle();
        expect(find.byType(MoviePlayerScreen), findsNothing);
        expect(find.text('detalle'), findsOneWidget);
        await expectLater(p.done, completes);
        expect((await SeriesWatchService.season('s1')).complete, isTrue);
      });

      testWidgets('si el siguiente no carga, avisa y vuelve', (tester) async {
        final p = playlist(episodes: 2, failNext: true);
        await pushEpisode(tester, p);
        await end(tester);
        await tester.pumpAndSettle();
        expect(find.byType(MoviePlayerScreen), findsNothing);
        expect(find.text('detalle'), findsOneWidget);
        await expectLater(p.done, completes);
        await tester.pump(const Duration(seconds: 5));
      });

      testWidgets('atrás sale de la serie', (tester) async {
        final p = playlist(episodes: 2);
        await pushEpisode(tester, p);
        // La primera atrás esconde la interfaz; la segunda sale.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(MoviePlayerScreen), findsNothing);
        await expectLater(p.done, completes);
      });
    });

    testWidgets('pasados los 3 min sale de Interesantes; antes no', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      MovieWatchlistService.instance.resetForTest();
      await MovieWatchlistService.instance.toggle(
        MovieItem(contentId: 'p1', name: 'Tenzing'),
      );
      await pushPlayer(tester);
      engine.startPlaying();

      // En el minuto 1 todavía no cuenta como empezada.
      await tester.pump(const Duration(seconds: 2));
      expect(MovieWatchlistService.instance.contains('p1'), isTrue);

      // En el 10 ya está en "Seguir viendo".
      engine.position = const Duration(minutes: 10);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect((await MovieProgressService.getProgress('p1'))?.canResume, isTrue);
      expect(MovieWatchlistService.instance.contains('p1'), isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('el sondeo hace una sola llamada al motor por vuelta', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pushPlayer(tester);
      engine.startPlaying();
      await tester.pump(const Duration(seconds: 3));

      expect(engine.count('getStatus'), greaterThanOrEqualTo(4));
      expect(engine.count('getPosition'), 0);
      expect(engine.count('getDuration'), 0);
      expect(engine.count('getBufferedPosition'), 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('un corte a mitad espera 90 s antes del error', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pushPlayer(tester);
      engine.startPlaying();
      await tester.pump();

      engine.events.add({'event': 'state', 'value': 'buffering'});
      await tester.pump(const Duration(seconds: 60));
      expect(find.byType(MoviePlayerErrorPanel), findsNothing);

      await tester.pump(const Duration(seconds: 31));
      expect(find.byType(MoviePlayerErrorPanel), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('al retomar, la posición 0 del arranque no borra el progreso', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await MovieProgressService.saveProgress(
        contentId: 'p1',
        currentPosition: const Duration(minutes: 40),
        totalDuration: const Duration(hours: 2),
      );
      await pushPlayer(tester, initialPositionSeconds: 40 * 60);
      // Todavía cargando: el motor dice 0 y pasan varios sondeos.
      engine.position = Duration.zero;
      await tester.pump(const Duration(seconds: 12));

      final progress = await MovieProgressService.getProgress('p1');
      expect(progress?.positionSeconds, 40 * 60);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('si un salto termina en error, reintentar no lo repite', (
      tester,
    ) async {
      await pumpPlayer(tester);

      // Salto al 1:10 que falla (como el 404 del proxy).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(engine.seeks, [
        const Duration(minutes: 1, seconds: 10).inMilliseconds,
      ]);
      engine.events.add({
        'event': 'error',
        'value': {'code': 2004, 'message': 'Source error'},
      });
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      engine.startPlaying();
      await tester.pump();

      // Vuelve al minuto 1 (antes del salto), no al 1:10 que falló.
      final reload = engine.calls.lastWhere((c) => c.method == 'setMedia');
      expect(
        (reload.arguments as Map)['startPositionMs'],
        const Duration(minutes: 1).inMilliseconds,
      );
      await finish(tester);
    });
  });
}
