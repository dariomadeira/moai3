import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/engine/engine_player_view.dart';
import 'package:moai3/features/movies/movie_player_format.dart';
import 'package:moai3/features/movies/screens/movie_player_screen.dart';
import 'package:moai3/features/movies/widgets/movie_player_osd.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/platform/platform_channels.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/services/movie_progress_service.dart';
import 'package:moai3/services/movie_watchlist_service.dart';
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

  void install(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(PlatformChannels.player, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'create':
          return {'handle': 1, 'textureId': 1};
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
    messenger.setMockStreamHandler(
      PlatformChannels.playerEvents(1),
      MockStreamHandler.inline(
        onListen: (_, sink) {
          events.stream.listen(sink.success);
        },
      ),
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(PlatformChannels.player, null);
      messenger.setMockStreamHandler(PlatformChannels.playerEvents(1), null);
    });
  }

  /// El video arrancó: primer cuadro y reproduciendo.
  void startPlaying() {
    events.add({'event': 'state', 'value': 'ready'});
    events.add({'event': 'playing', 'value': true});
    events.add({'event': 'firstFrame'});
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
    }) async {
      useSpanishTranslations();
      SharedPreferences.setMockInitialValues(prefs);
      final settings = TvSettingsProvider(await AppPreferences.init());
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      engine = _FakeEngine()..install(tester);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            home: MoviePlayerScreen(
              movie: MovieItem(contentId: 'p1', name: 'Tenzing'),
              stream: const ResolvedPlayStream(
                streamUrl: 'https://example.com/v.m3u8',
                quality: '1080P HD',
                audioInfo: 'esp',
                subtitles: [
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

      // Al volver a arrancar, retoma en el minuto 1.
      engine.startPlaying();
      await tester.pump();
      expect(engine.seeks, [const Duration(minutes: 1).inMilliseconds]);
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
      expect(engine.seeks.last, const Duration(minutes: 1).inMilliseconds);
      await finish(tester);
    });
  });
}
