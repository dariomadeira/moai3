// Red de seguridad del modo oscuro: fotos del modo claro tal como está.
// Mientras se arma el oscuro, las de `light/` no pueden cambiar ni un píxel.
//
// Las de `dark/` son las del oscuro en obra: cambian en cada fase (se
// regeneran a propósito y se miran).
//
// Si un cambio del claro es a propósito, se regeneran con:
//   flutter test test/goldens --update-goldens
// y se miran las fotos nuevas (test/goldens/light/) antes de aceptarlas.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/widgets/tv_common/tv_tile.dart';
import 'package:moai3/features/movies/screens/movie_detail_screen.dart';
import 'package:moai3/widgets/tv_common/moai_ambient_background.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/services/movie_watchlist_service.dart';
import 'package:moai3/features/home/widgets/tv_vertical_nav_rail.dart';
import 'package:moai3/features/home/home_section.dart';
import 'package:moai3/features/home/areas/home_dashboard_area.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/features/movies/screens/series_detail_screen.dart';
import 'package:moai3/features/movies/widgets/tv_movie_genre_chip.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/models/series_models.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_accent_colors.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_theme.dart';
import 'package:moai3/widgets/buttons/moai_pill_button.dart';
import 'package:moai3/widgets/buttons/tv_back_pill.dart';
import 'package:moai3/widgets/tv_common/moai_count_badge.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/moai_status_tag.dart';
import 'package:moai3/widgets/tv_common/tv_meta_pill.dart';
import 'package:moai3/widgets/tv_common/tv_value_chip.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/real_fonts.dart';
import '../helpers/spanish_translations.dart';

/// El acento por defecto (el azul de Cleanly).
final Color _seed = MoaiAccentColors.seedAt(0);

/// Un fondo fijo parecido al ambiente (lila claro): el cristal es
/// translúcido y así se nota cualquier cambio de su relleno.
const _lightBackdrop = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE4E7F2), Color(0xFFD9D2EA), Color(0xFFF0E6E0)],
  ),
);

/// El mismo, de noche: azul casi negro con algo de violeta.
const _darkBackdrop = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF151824), Color(0xFF1C1830), Color(0xFF221B1E)],
  ),
);

Future<void> _pumpSheet(
  WidgetTester tester,
  Widget child, {
  required bool dark,
}) async {
  tester.view.physicalSize = const Size(960, 540);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // Lo que hace la app al armar el tema (el degradado de los títulos).
  if (dark) {
    HomeClock.setAccent(_seed, dark: true);
    addTearDown(() => HomeClock.setAccent(const Color(0xFF2B4CFF)));
  }
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? MoaiTheme.dark(_seed) : MoaiTheme.light(_seed),
      home: DecoratedBox(
        decoration: dark ? _darkBackdrop : _lightBackdrop,
        child: Material(type: MaterialType.transparency, child: child),
      ),
    ),
  );
  await _loadImages(tester);
}

/// Deja que terminen de cargar las imágenes (el fondo ambiente y su copia
/// desenfocada del vidrio esmerilado): se decodifican fuera del reloj falso
/// del test. Sin esto, si un test anterior ya las había cargado la foto
/// salía distinta.
Future<void> _loadImages(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump();
  }
}

/// Un rótulo y su muestra.
Widget _sample(String label, Widget child) => Builder(
  builder: (context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: MoaiText.body(
          context,
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 4),
      child,
    ],
  ),
);

Widget _box(BoxDecoration decoration, {String text = 'Texto'}) => Builder(
  builder: (context) => Container(
    width: 110,
    height: 40,
    alignment: Alignment.center,
    decoration: decoration,
    child: Text(
      text,
      style: MoaiText.body(
        context,
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  ),
);

Widget _glass({
  bool solid = false,
  bool focused = false,
  bool elevated = true,
  bool frosted = false,
  Color? tint,
}) => MoaiGlass(
  width: 110,
  height: 40,
  solid: solid,
  focused: focused,
  elevated: elevated,
  frosted: frosted,
  tint: tint,
  borderRadius: 12,
  alignment: Alignment.center,
  child: const Text('Cristal'),
);

/// Piezas del sistema de cristal y de la ficha, en el tema claro.
class _Sheet extends StatelessWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 14,
        runSpacing: 12,
        children: [
          _sample('chip', _glass()),
          _sample('sólido', _glass(solid: true)),
          _sample('foco', _glass(focused: true)),
          _sample('sólido+foco', _glass(solid: true, focused: true)),
          _sample('sin sombra', _glass(elevated: false)),
          _sample('esmerilado', _glass(frosted: true)),
          _sample('teñido', _glass(tint: scheme.primary)),
          _sample(
            'botón',
            _box(moaiGlassButtonDecoration(scheme, focused: false)),
          ),
          _sample(
            'botón foco',
            _box(moaiGlassButtonDecoration(scheme, focused: true)),
          ),
          _sample(
            'botón resalt.',
            _box(
              moaiGlassButtonDecoration(
                scheme,
                focused: false,
                highlighted: true,
              ),
            ),
          ),
          _sample('etiqueta', _box(moaiGlassTagDecoration(scheme))),
          _sample(
            'etiqueta tinte',
            _box(moaiGlassTagDecoration(scheme, tint: scheme.tertiary)),
          ),
          _sample('chip deco', _box(moaiGlassChipDecoration(scheme))),
          _sample(
            'chip resalt.',
            _box(moaiGlassChipDecoration(scheme, highlighted: true)),
          ),
          _sample('pozo', _box(moaiGlassWellDecoration(scheme))),
          _sample('video', _box(moaiVideoGlassDecoration())),
          _sample(
            'meta',
            TvMetaPill(
              dense: true,
              color: scheme.tertiaryContainer,
              foreground: scheme.onTertiaryContainer,
              icon: MoaiIcons.vodReleaseDate,
              label: '2024',
            ),
          ),
          _sample('género', const TvMovieGenreChip(label: 'Drama')),
          _sample(
            'estado',
            MoaiStatusTag(label: 'EN VIVO', color: scheme.error),
          ),
          _sample('contador', const MoaiCountBadge(count: 3)),
          _sample(
            'valor',
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TvValueChip(text: 'Sí', isFocused: false),
                SizedBox(width: 6),
                TvValueChip(text: 'No', isFocused: true),
              ],
            ),
          ),
          _sample(
            'pastillas',
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MoaiPillButton(
                  kind: MoaiPillButtonKind.filled,
                  label: 'Ver',
                  selected: true,
                ),
                SizedBox(width: 6),
                MoaiPillButton(kind: MoaiPillButtonKind.glass, label: 'Info'),
              ],
            ),
          ),
          _sample('atrás', const TvBackPill()),
          _sample(
            'carga',
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(value: 0.7),
            ),
          ),
          _sample(
            'textos',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Título',
                  style: MoaiText.display(
                    context,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  'Secundario',
                  style: MoaiText.body(
                    context,
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Acento',
                  style: MoaiText.body(
                    context,
                    fontSize: 13,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Como llega del portal (el de `series_detail_screen_test`, recortado).
SeriesSeasonDetail _season(String id, int season) {
  final raw = <String, dynamic>{
    'contentId': id,
    'name': 'Caballos lentos T$season',
    'alias': 'Slow Horses S$season',
    'director': 'Mick Herron',
    'actorDisplay': 'Gary Oldman,Jack Lowden',
    'score': 8.3,
    'releaseTime': '202$season-09-16',
    'tags': 'Drama,Thriller',
    'description': 'Agentes del MI5 en un departamento de vertedero.',
    'programType': 'teleplay',
    'simpleProgramList': [
      for (var n = 1; n <= 30; n++)
        {
          'contentId': '$id-e$n',
          'name': 'Caballos lentos T${season}_$n',
          'duration': '',
          'seriesNumber': n,
          'posterList': [],
        },
    ],
    'sameSeasonSeriesList': [
      for (var s = 1; s <= 14; s++) {'contentId': 's$s', 'seasonNumber': s},
    ],
    'posterList': [],
  };
  return SeriesSeasonDetail.fromAsset(
    raw,
    MovieItem.fromJson({...raw, 'year': '202$season'}),
  )!;
}

void main() {
  setUpAll(loadRealFonts);

  for (final (mode, dark) in [('light', false), ('dark', true)]) {
    group(mode, () {
      testWidgets('inicio con el rail', (tester) async {
        useSpanishTranslations();
        SharedPreferences.setMockInitialValues({});
        MovieWatchlistService.instance.resetForTest();
        final prefs = await AppPreferences.init();
        DateTime now() => DateTime(2026, 11, 10, 20, 30);
        await _pumpSheet(
          tester,
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) =>
                    CalendarProvider(preferences: prefs, startTicker: false),
              ),
              ChangeNotifierProvider(
                create: (_) => FeaturedMoviesProvider()
                  ..setAvailableSections({
                    FeaturedMoviesProvider.sectionMovies,
                    FeaturedMoviesProvider.sectionSeries,
                  }),
              ),
              ChangeNotifierProvider(create: (_) => TvSettingsProvider(prefs)),
            ],
            child: Stack(
              children: [
                const Positioned.fill(child: MoaiAmbientBackground()),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TvVerticalNavRail(
                      selected: HomeSection.home,
                      railScopeNode: FocusScopeNode(),
                      railFocusNode: FocusNode(),
                      onSelected: (_) {},
                      onFocusRight: () {},
                      onExit: () {},
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: HomeDashboardArea(
                          onExitLeft: () {},
                          romManager: ArcadeRomManagerService(
                            preferences: prefs,
                          ),
                          now: now,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          dark: dark,
        );
        await tester.pumpAndSettle();
        await _loadImages(tester);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MultiProvider),
          matchesGoldenFile('$mode/inicio.png'),
        );
      });

      testWidgets('detalle de una película', (tester) async {
        useSpanishTranslations();
        SharedPreferences.setMockInitialValues({});
        MovieWatchlistService.instance.resetForTest();
        final prefs = await AppPreferences.init();
        await _pumpSheet(
          tester,
          ChangeNotifierProvider(
            create: (_) => TvSettingsProvider(prefs),
            child: MovieDetailScreen(
              movie: MovieItem.fromJson({
                'contentId': 'm1',
                'name': 'La gran estafa',
                'alias': "Ocean's Eleven",
                'director': 'Steven Soderbergh',
                'actorDisplay': 'George Clooney,Brad Pitt,Julia Roberts',
                'score': 7.8,
                'year': '2001',
                'tags': 'Crimen,Comedia',
                'description':
                    'Danny Ocean junta a once especialistas para robar tres '
                    'casinos de Las Vegas en una sola noche.',
                'posterList': [],
              }),
              resolveStream: (_) async => null,
              openTrailer: (_) async => true,
            ),
          ),
          dark: dark,
        );
        await tester.pumpAndSettle();
        await _loadImages(tester);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MovieDetailScreen),
          matchesGoldenFile('$mode/pelicula_detalle.png'),
        );
      });

      testWidgets('fichas de Ajustes', (tester) async {
        final first = FocusNode();
        addTearDown(first.dispose);
        await _pumpSheet(
          tester,
          Center(
            child: MoaiGlass(
              frosted: true,
              borderRadius: MoaiGlass.panelRadius,
              width: 520,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TvTile(
                    focusNode: first,
                    icon: MoaiIcons.darkMode,
                    label: 'Modo oscuro',
                    description: 'La app con fondo oscuro',
                  ),
                  const SizedBox(height: 10),
                  TvTile(
                    focusNode: FocusNode(),
                    icon: MoaiIcons.vodReleaseDate,
                    label: 'Frecuencia del catálogo',
                    description: 'Cada cuánto se baja de nuevo',
                  ),
                ],
              ),
            ),
          ),
          dark: dark,
        );
        first.requestFocus();
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(Center).first,
          matchesGoldenFile('$mode/fichas_ajustes.png'),
        );
      });

      testWidgets('piezas del cristal', (tester) async {
        await _pumpSheet(tester, const _Sheet(), dark: dark);
        await expectLater(
          find.byType(_Sheet),
          matchesGoldenFile('$mode/piezas.png'),
        );
      });

      testWidgets('detalle de una serie', (tester) async {
        useSpanishTranslations();
        SharedPreferences.setMockInitialValues({});
        final prefs = await AppPreferences.init();
        await _pumpSheet(
          tester,
          ChangeNotifierProvider(
            create: (_) => TvSettingsProvider(prefs),
            child: SeriesDetailScreen(
              series: MovieItem(
                contentId: 's1',
                name: 'Caballos lentos T1',
                programType: 'teleplay',
              ),
              fetchSeason: (id) async =>
                  _season(id, int.parse(id.substring(1))),
            ),
          ),
          dark: dark,
        );
        await tester.pumpAndSettle();
        await _loadImages(tester);
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(SeriesDetailScreen),
          matchesGoldenFile('$mode/serie_detalle.png'),
        );
      });
    });
  }
}
