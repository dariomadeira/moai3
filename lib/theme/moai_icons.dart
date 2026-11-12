import 'package:flutter/widgets.dart';
import 'package:hugeicons_plus/hugeicons_plus.dart';
import 'package:moai3/utils/text_normalize.dart';

/// Catálogo único de íconos de Moai (SPEC-50 §4).
///
/// Toda la app usa estas constantes; nadie más importa paquetes de íconos
/// (`test/icons_usage_test.dart`). Familia única: HugeIcons Stroke-Rounded
/// (https://hugeicons.com/icons/stroke-rounded) vía [HugeIcons].
/// Cambiar un valor acá cambia todos sus usos.
///
/// Secciones:
/// 1. Navegación — rail lateral
/// 2. TV — acordeón de paneles y pestañas
/// 3. TV — visor, canales y extensiones
/// 4. TV — favoritos y grupos (marcadores)
/// 5. TV — categorías de canales
/// 6. Agenda
/// 7. Arcade
/// 8. Amigos y Miremos juntos
/// 9. Ajustes
/// 10. Clima y ubicación
/// 11. Calibración de pantalla
/// 12. Acciones y estados comunes
/// 13. Flechas
/// 14. Películas y series (VOD)
/// 15. Teclado en pantalla y PIN
/// 16. Arranque
///
/// Tamaños: usar siempre [MoaiIconSizes], nunca un número suelto.
abstract final class MoaiIcons {
  MoaiIcons._();

  // ---------------------------------------------------------------------------
  // 1. Navegación — rail lateral
  // Consumidor: `features/home/widgets/tv_vertical_nav_rail.dart`.
  // ---------------------------------------------------------------------------

  /// Rail «Inicio» (sin seleccionar).
  static const railHome = HugeIcons.home04;

  /// Rail «Inicio» (seleccionado).
  static const railHomeSelected = HugeIcons.home04;

  /// Rail «TV» (sin seleccionar).
  static const railTv = HugeIcons.modernTv;

  /// Rail «TV» (seleccionado).
  static const railTvSelected = HugeIcons.modernTv;

  /// Rail del visor de TV nuevo (en rediseño, al lado del de siempre).
  static const railLiveTv = HugeIcons.tv01;

  /// Rail «Destacados» (sin seleccionar).
  static const railFeatured = HugeIcons.video01;

  /// Rail «Destacados» (seleccionado).
  static const railFeaturedSelected = HugeIcons.video01;

  /// Rail «Películas» (sin seleccionar).
  static const railMovies = HugeIcons.clapperboard;

  /// Rail «Películas» (seleccionado).
  static const railMoviesSelected = HugeIcons.clapperboard;

  /// Series (rail y pestaña): `strokeRoundedTvMinimalPlay` de Hugeicons, que no está en
  /// `hugeicons_plus` 0.1.1 (es de un set más nuevo). Copiado del paquete
  /// oficial `hugeicons` 1.2.0 como SVG de 24×24 con el trazo de 1,5 de los
  /// demás; se dibuja con [MoaiSvgIcon].
  static const seriesSvg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
      'fill="none" stroke="#000" stroke-width="1.5" stroke-linecap="round" '
      'stroke-linejoin="round">'
      '<path d="M2 14C2 10.2288 2 8.34315 3.17157 7.17157C4.34315 6 6.22876 6 '
      '10 6H14C17.7712 6 19.6569 6 20.8284 7.17157C22 8.34315 22 10.2288 22 '
      '14C22 17.7712 22 19.6569 20.8284 20.8284C19.6569 22 17.7712 22 14 22H10'
      'C6.22876 22 4.34315 22 3.17157 20.8284C2 19.6569 2 17.7712 2 14Z"/>'
      '<path d="M14.957 14.3384C14.8182 14.8756 14.1619 15.2552 12.8494 '
      '16.0144C11.5806 16.7484 10.9462 17.1153 10.4349 16.9678C10.2236 16.9068 '
      '10.031 16.791 9.87567 16.6315C9.5 16.2456 9.5 15.497 9.5 14C9.5 12.503 '
      '9.5 11.7544 9.87567 11.3685C10.031 11.209 10.2236 11.0932 10.4349 '
      '11.0322C10.9462 10.8847 11.5806 11.2516 12.8494 11.9856C14.1619 12.7448 '
      '14.8182 13.1244 14.957 13.6616C15.0143 13.8834 15.0143 14.1166 14.957 '
      '14.3384Z"/>'
      '<path d="M9 3L12 6L16 2"/>'
      '</svg>';

  /// Detalle de una serie, "N temporadas": `strokeRoundedSatelliteDish` de
  /// Hugeicons, que tampoco está en `hugeicons_plus` (como [seriesSvg]).
  static const seriesSeasonsSvg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
      'fill="none" stroke="#000" stroke-width="1.5" stroke-linecap="round" '
      'stroke-linejoin="round">'
      '<path d="M2.49229 13.5818C2.47031 17.9768 6.01534 21.5218 10.4103 '
      '21.4998C11.4998 21.4944 12.5393 21.2702 13.4869 20.8692C14.5667 20.4122 '
      '15.1067 20.1837 15.2594 19.4004C15.4121 18.6171 14.8913 18.0963 13.8499 '
      '17.0549L6.93724 10.1422C5.89578 9.10076 5.37506 8.58003 4.59172 '
      '8.73274C3.80838 8.88545 3.57988 9.42536 3.1229 10.5052C2.72188 11.4528 '
      '2.49774 12.4923 2.49229 13.5818Z"/>'
      '<path d="M13.4922 6C15.9775 6 17.9922 8.01472 17.9922 10.5"/>'
      '<path d="M13.4922 2.5C17.9105 2.5 21.4922 6.08172 21.4922 10.5"/>'
      '<path d="M13.4932 10.5L10.3945 13.5995"/>'
      '</svg>';

  /// Rail «Agenda» (sin seleccionar).
  static const railCalendar = HugeIcons.calendar03;

  /// Rail «Agenda» (seleccionado).
  static const railCalendarSelected = HugeIcons.calendar03;

  /// Rail «Descuentos» (sin seleccionar / seleccionado).
  static const railDiscounts = HugeIcons.percentSquare;
  static const railDiscountsSelected = HugeIcons.percentSquare;

  /// Rail «Arcade» (sin seleccionar).
  static const railArcade = HugeIcons.joystick05;

  /// Rail «Arcade» (seleccionado).
  static const railArcadeSelected = HugeIcons.joystick05;

  /// Rail «Ajustes» (sin seleccionar).
  static const railSettings = HugeIcons.settings01;

  /// Rail «Ajustes» (seleccionado).
  static const railSettingsSelected = HugeIcons.settings01;

  // ---------------------------------------------------------------------------
  // 2. TV — acordeón de paneles y pestañas
  // Consumidores: `features/home/areas/`, `features/home/widgets/tv_tab_bar.dart`.
  // ---------------------------------------------------------------------------

  /// Acordeón «Grupos» (`home_panel_countries` → texto UI "Grupos").
  /// Panel: países/fuentes en el explorador. Grilla 2x2.
  static const tvAccordionGrupos = HugeIcons.circlePile;

  /// Acordeón «Categorías» (`home_panel_categories`). Menú cuadrado.
  static const tvAccordionCategorias = HugeIcons.menuSquare;

  /// Acordeón «Canales» (`home_panel_channels`). Control remoto.
  static const tvAccordionCanales = HugeIcons.remoteControl;

  /// Acordeón «Inicio» (`home_panel_home_title`).
  static const tvAccordionHome = HugeIcons.home04;

  /// Acordeón «Destacados» (`movies_panel_featured_title`).
  static const tvAccordionFeatured = HugeIcons.video01;

  /// Acordeón «Películas» (`movies_panel_movies_title`).
  static const tvAccordionMovies = HugeIcons.clapperboard;

  /// Acordeón «Series» (`movies_panel_series_title`).
  static const tvAccordionSeries = HugeIcons.film01;

  /// Pestaña «Explorar» idle (`home_tab_explore`). Brújula / compass.
  static const tvTabExplorar = HugeIcons.navigation05;

  /// Pestaña «Explorar» selected.
  static const tvTabExplorarSelected = HugeIcons.navigation05;

  /// Pestaña «Buscar» idle (`home_tab_search`). Lupa.
  static const tvTabBuscar = HugeIcons.search01;

  /// Pestaña «Buscar» selected.
  static const tvTabBuscarSelected = HugeIcons.search01;

  /// Pestaña «Marcadores» idle (`home_tab_groups`). Marcador / bookmark.
  static const tvTabMarcadores = HugeIcons.bookmark02;

  /// Pestaña «Marcadores» selected.
  static const tvTabMarcadoresSelected = HugeIcons.bookmark02;

  // ---------------------------------------------------------------------------
  // 3. TV — visor, canales y extensiones
  // ---------------------------------------------------------------------------

  /// Pill país/grupo del canal (ej. "Argentina"). Grilla 2×2.
  static const tvViewerPillCountry = HugeIcons.circlePile;

  /// Pill categoría del canal (ej. "Aire"). Menú cuadrado.
  static const tvViewerPillCategory = HugeIcons.menuSquare;

  /// Pill extensión/plugin del canal (ej. "ar"). Pieza de puzzle.
  static const tvViewerPillPlugin = HugeIcons.puzzle;

  /// Visor vacío de TV sin canal seleccionado o sin canales (`empty_viewer_panel.dart`).
  static const tvEmptyViewer = HugeIcons.tv01;

  /// Sin logo / logo fallido en la grilla o lista de canales.
  static const tvChannelLogoFallback = HugeIcons.modernTvIssue;

  /// Estado vacío sin canales (`browser_channels_empty`).
  /// Consumidor: `features/channel_browser/widgets/channel_list_panel.dart`
  static const tvChannelsEmpty = HugeIcons.search01;

  /// Pill canales totales / fuentes en cabecera de extensiones. Enchufe plug.
  static const tvSourcesTotalChannels = HugeIcons.plug01;

  /// Icono para campo de URL de extensiones (TvTextField). Link.
  static const tvSourcesUrlInput = HugeIcons.link01;

  /// Icono botón instalar en barra superior de extensiones. Bandeja de descarga.
  static const tvSourcesInstallAction = HugeIcons.inboxDownload;

  /// Ítem de país/grupo en el panel Grupos (`country_list_panel.dart`).
  static const tvCountryItem = HugeIcons.globe;

  /// Servidor actual del canal en el visor (`tv_viewer_panel.dart`).
  static const server = HugeIcons.serverStack01;

  /// Botón «saltar servidor» (`server_skip_button.dart`).
  static const serverSkip = HugeIcons.serverStack02;

  // ---------------------------------------------------------------------------
  // 4. TV — favoritos y grupos (marcadores)
  // ---------------------------------------------------------------------------

  /// Crear grupo de marcadores (`CreateGroupButton`). Plus / +.
  static const tvFavoritesAdd = HugeIcons.add01;

  /// Vaciar favoritos (`ClearFavoritesButton`). Papelera.
  static const tvFavoritesClear = HugeIcons.delete02;

  /// Toggle favorito idle — no está en favoritos (`FavoriteButton`).
  static const tvFavoritesHeart = HugeIcons.favourite;

  /// Toggle favorito active — canal en favoritos (`FavoriteButton`).
  static const tvFavoritesHeartSelected = HugeIcons.favourite;

  /// Icono cabecera modal crear grupo de marcadores (`CreateGroupButton`).
  static const tvGroupCreateDialogTitle = HugeIcons.bookmark01;

  /// Icono campo de texto nombre en modal crear grupo de marcadores (`CreateGroupButton`).
  static const tvGroupCreateDialogInput = HugeIcons.keyboard;

  /// Icono por defecto de un grupo de marcadores.
  static const tvBookmarkGroupLeading = HugeIcons.bookmark02;

  /// Botón «crear grupo» (`create_group_button.dart`).
  static const groupCreate = HugeIcons.bookmarkAdd01;

  /// Ícono de grupo «Favoritos» (clave guardada `'favorite'`).
  static const groupIconFavorite = HugeIcons.favourite;

  /// Ícono de grupo «Sin adultos (+18)» (clave guardada `'no_adults'`).
  static const groupIconAdults = HugeIcons.lockPassword;

  /// Ícono de grupo «Fútbol» (clave guardada `'sports_soccer'`).
  static const groupIconSoccer = HugeIcons.football;

  /// Ícono de grupo «Películas» (clave guardada `'movie'`).
  static const groupIconMovies = HugeIcons.clapperboard;

  /// Ícono de grupo «Infantil» (clave guardada `'child_hat'`).
  static const groupIconKids = HugeIcons.balloon;

  /// Ícono de grupo «Noticias» (clave guardada `'newspaper'`).
  static const groupIconNews = HugeIcons.news;

  /// Ícono de grupo «TV general» (clave guardada `'tv_gen'`).
  static const groupIconTv = HugeIcons.tv01;

  /// Ícono de grupo «Idioma» (clave guardada `'language'`).
  static const groupIconLanguage = HugeIcons.languageSquare;

  /// Clave de ícono guardada en el grupo → ícono (ver [groupIconFor]).
  static const Map<String, IconData> _groupIcons = {
    'bookmark': tvBookmarkGroupLeading,
    'favorite': groupIconFavorite,
    'no_adults': groupIconAdults,
    'sports_soccer': groupIconSoccer,
    'movie': groupIconMovies,
    'child_hat': groupIconKids,
    'newspaper': groupIconNews,
    'tv_gen': groupIconTv,
    'language': groupIconLanguage,
  };

  /// Ícono de un grupo por su clave (o [tvBookmarkGroupLeading]).
  static IconData groupIconFor(String iconKey) =>
      _groupIcons[iconKey] ?? tvBookmarkGroupLeading;

  // ---------------------------------------------------------------------------
  // 5. TV — categorías de canales
  // Mapa por nombre de categoría. Consumidor: `widgets/cards/category_card.dart` → [tvCategoryIconFor].
  // ---------------------------------------------------------------------------

  /// «Aire» — ondas / señal.
  static const tvCategoryAire = HugeIcons.liveStreaming01;

  /// «Interior» / «Provinciales» — ciudad.
  static const tvCategoryInterior = HugeIcons.city01;

  /// «Deportes» — pelota de fútbol.
  static const tvCategoryDeportes = HugeIcons.football;

  /// «Noticias» — periódico / noticias.
  static const tvCategoryNoticias = HugeIcons.news;

  /// «Infantiles» / «Infantil» — globo.
  static const tvCategoryInfantiles = HugeIcons.balloon;

  /// «Entretenimiento» / «Teleshows» — ticket.
  static const tvCategoryEntretenimiento = HugeIcons.ticket01;

  /// «Comedia» — máscaras de teatro.
  static const tvCategoryComedia = HugeIcons.maskTheater01;

  /// «Reality» — ojo.
  static const tvCategoryReality = HugeIcons.eye;

  /// «Anime» — animación / destellos.
  static const tvCategoryAnime = HugeIcons.sparkles;

  /// «Cocina» — gorro de chef.
  static const tvCategoryCocina = HugeIcons.chefHat;

  /// «Radios» — radio.
  static const tvCategoryRadios = HugeIcons.radio01;

  /// «Series» — rollo de película.
  static const tvCategorySeries = HugeIcons.film01;

  /// «Películas» / «Cine» / «Cine y Series» — claqueta.
  static const tvCategoryCine = HugeIcons.clapperboard;

  /// «Documentales» — libro.
  static const tvCategoryDocumentales = HugeIcons.book02;

  /// «Música» / «Conciertos» — nota musical.
  static const tvCategoryMusica = HugeIcons.musicNote01;

  /// «Niños» — carita feliz.
  static const tvCategoryNinos = HugeIcons.smile;

  /// «Educación» — birrete de graduación.
  static const tvCategoryEducacion = HugeIcons.graduationCap;

  /// «Religión» / «Religioso» — rayo / energía espiritual.
  static const tvCategoryReligion = HugeIcons.church;

  /// «Telenovelas» / «Novelas» — corazón.
  static const tvCategoryNovelas = HugeIcons.heart;

  /// «Cultura» / «Cultural» — libro.
  static const tvCategoryCultura = HugeIcons.book01;

  /// «General» — control remoto.
  static const tvCategoryGeneral = HugeIcons.remoteControl;

  /// «Otros» — menú.
  static const tvCategoryOtros = HugeIcons.menu01;

  /// «Internacional» — globo terráqueo.
  static const tvCategoryInternacional = HugeIcons.globe;

  /// «Comunitarios» — grupo de usuarios.
  static const tvCategoryComunitarios = HugeIcons.userGroup;

  /// «Culturales» — teatro.
  static const tvCategoryCulturales = HugeIcons.theater;

  /// «Adultos» — candado.
  static const tvCategoryAdultos = HugeIcons.lockPassword;

  /// Fallback si la categoría no está en el mapa.
  static const tvCategoryFallback = HugeIcons.tv01;

  /// Nombre de categoría (exacto) → icono. Alias y sinónimos incluidos.
  static const Map<String, IconData> tvCategoryIcons = {
    'Aire': tvCategoryAire,
    'Interior': tvCategoryInterior,
    'Provinciales': tvCategoryInterior,
    'Deportes': tvCategoryDeportes,
    'Noticias': tvCategoryNoticias,
    'Infantiles': tvCategoryInfantiles,
    'Infantil': tvCategoryInfantiles,
    'Entretenimiento': tvCategoryEntretenimiento,
    'Comedia': tvCategoryComedia,
    'Reality': tvCategoryReality,
    'Anime': tvCategoryAnime,
    'Cocina': tvCategoryCocina,
    'Radios': tvCategoryRadios,
    'Series': tvCategorySeries,
    'Películas': tvCategoryCine,
    'Cine y Series': tvCategoryCine,
    'Documentales': tvCategoryDocumentales,
    'Música': tvCategoryMusica,
    'Niños': tvCategoryNinos,
    'Educación': tvCategoryEducacion,
    'Religión': tvCategoryReligion,
    'Religioso': tvCategoryReligion,
    'Conciertos': tvCategoryMusica,
    'Telenovelas': tvCategoryNovelas,
    'Novelas': tvCategoryNovelas,
    'Cine': tvCategoryCine,
    'Cultura': tvCategoryCultura,
    'Cultural': tvCategoryCultura,
    'General': tvCategoryGeneral,
    'Teleshows': tvCategoryEntretenimiento,
    'Otros': tvCategoryOtros,
    'Internacional': tvCategoryInternacional,
    'Comunitarios': tvCategoryComunitarios,
    'Culturales': tvCategoryCulturales,
    'Adultos': tvCategoryAdultos,
  };

  static final Map<String, IconData> _tvCategoryIconsNormalized = {
    for (final e in tvCategoryIcons.entries) normalizeText(e.key): e.value,
  };

  /// Resuelve el icono de una categoría por nombre, sin importar tildes ni
  /// mayúsculas (o [tvCategoryFallback]).
  static IconData tvCategoryIconFor(String category) =>
      _tvCategoryIconsNormalized[normalizeText(category)] ?? tvCategoryFallback;

  // ---------------------------------------------------------------------------
  // 6. Agenda
  // Consumidores: `features/calendar/`, `features/home/areas/home_calendar_area.dart`,
  // `state/calendar_provider.dart`.
  // ---------------------------------------------------------------------------

  /// Panel «Eventos» de la Agenda y su acceso en Ajustes.
  static const calendarEvents = HugeIcons.calendar03;

  /// Panel «Suscripciones» de la Agenda.
  static const calendarSubscriptions = HugeIcons.calendarPlus;

  /// Botón «ir a hoy» (`calendar_events_panel.dart`).
  static const calendarToday = HugeIcons.calendarCheck;

  /// Botón «recargar» de la Agenda (`calendar_events_panel.dart`).
  static const calendarRefresh = HugeIcons.calendarSync;

  /// Día sin eventos (`calendar_day_column.dart`).
  static const calendarEmptyDay = HugeIcons.calendarRemove01;

  /// Aviso de evento en vivo (`calendar_provider.dart`).
  static const calendarLive = HugeIcons.playCircle;

  /// Suscripción F1 — bandera de competición.
  static const calendarSubF1 = HugeIcons.racingFlag;

  /// Suscripción LPF AR — fútbol.
  static const calendarSubLpf = HugeIcons.football;

  /// Suscripción Champions League — trofeo / campeón.
  static const calendarSubChampions = HugeIcons.champion;

  /// Suscripción Premier League — fútbol.
  static const calendarSubPremier = HugeIcons.football;

  /// Suscripción NFL — fútbol americano.
  static const calendarSubNfl = HugeIcons.americanFootball;

  /// Suscripción NBA — básquetbol.
  static const calendarSubNba = HugeIcons.basketball01;

  /// Deporte sin ícono propio — estrella de premio.
  static const calendarSubFallback = HugeIcons.starAward01;

  /// Mapa id de suscripción → icono (alineado con [CalendarProvider.defaultSubscriptions]).
  static const Map<String, IconData> calendarSubIcons = {
    'f1': calendarSubF1,
    'lpf_ar': calendarSubLpf,
    'champions': calendarSubChampions,
    'premier': calendarSubPremier,
    'nfl': calendarSubNfl,
    'nba': calendarSubNba,
  };

  /// Resuelve el icono de una suscripción por id (heurística + [calendarSubFallback]).
  static IconData calendarSubIconFor(String subscriptionId) {
    final exact = calendarSubIcons[subscriptionId];
    if (exact != null) return exact;
    final lower = subscriptionId.toLowerCase();
    if (lower.contains('f1')) return calendarSubF1;
    if (lower.contains('nfl') || lower.contains('football')) {
      return calendarSubNfl;
    }
    if (lower.contains('nba') || lower.contains('basket')) {
      return calendarSubNba;
    }
    if (lower.contains('champions')) return calendarSubChampions;
    if (lower.contains('premier') ||
        lower.contains('lpf') ||
        lower.contains('soccer')) {
      return calendarSubLpf;
    }
    return calendarSubFallback;
  }

  /// Cabecera del modal (título del evento).
  static const calendarDialogTitle = HugeIcons.calendar03;

  /// Tile «Horario».
  static const calendarDialogTime = HugeIcons.clock01;

  /// Tile «Deporte».
  static const calendarDialogSport = HugeIcons.football;

  /// Tile «Transmisión».
  static const calendarDialogBroadcast = HugeIcons.modernTv;

  // ---------------------------------------------------------------------------
  // 7. Arcade
  // Consumidores: `features/games/`, `features/home/areas/home_arcade_area.dart`.
  // ---------------------------------------------------------------------------

  /// 1. Seleccionar juego Arcade (Pac-Man; también el botón «Cambiar» de la
  /// tarjeta del Inicio)
  static const arcadeActionSelectGame = HugeIcons.pacman01;

  /// 2. Configurar Gamepad Arcade (gamepad)
  static const arcadeActionConfigGamepad = HugeIcons.gameController03;

  /// 3. Iniciar juego Arcade (play)
  static const arcadeActionStartGame = HugeIcons.play;

  /// Refrescar catálogo de ROMs (refresh)
  static const arcadeCatalogRefresh = HugeIcons.refresh03;

  /// Ícono de ROM / Juego en catálogo
  static const arcadeRomItem = HugeIcons.aircraftGame;

  /// Ícono del badge/pill de instalados en cabecera de Arcade (gameboy)
  static const arcadeRomInstalledBadge = HugeIcons.gameboy;

  /// Ícono de la tarjeta de juego instalado (Pac-Man)
  static const arcadeRomCard = HugeIcons.pacman02;

  /// Eliminar ROM instalada (papelera)
  static const arcadeRomDelete = HugeIcons.delete02;

  /// Control de juego (configuración, invitaciones, controles conectados).
  static const gamepad = HugeIcons.gameController03;

  /// Control de juego (pantalla de juego, acordeón Arcade).
  static const gamepadFilled = HugeIcons.gameController03;

  /// Control remoto del TV como mando (`arcade_screen.dart`).
  static const remote = HugeIcons.remoteControl;

  /// Cruceta del control en pantalla (`arcade_controller_overlay.dart`).
  static const dpadUp = HugeIcons.chevronUp;

  /// Cruceta del control en pantalla (`arcade_controller_overlay.dart`).
  static const dpadDown = HugeIcons.chevronDown;

  /// Cruceta del control en pantalla (`arcade_controller_overlay.dart`).
  static const dpadLeft = HugeIcons.chevronLeft;

  /// Cruceta del control en pantalla (`arcade_controller_overlay.dart`).
  static const dpadRight = HugeIcons.chevronRight;

  // ---------------------------------------------------------------------------
  // 8. Amigos y Miremos juntos
  // Consumidores: `widgets/dialogs/tv_friends*`, `widgets/player/watch_party_overlay.dart`, ajustes.
  // ---------------------------------------------------------------------------

  /// Amigos / jugar con un amigo.
  static const friends = HugeIcons.userGroup;

  /// Mis amigos: el modal y su ítem en Ajustes › Miremos juntos
  /// (Contact01, stroke rounded).
  static const watchPartyFriends = HugeIcons.contact01;

  /// Sin amigos todavía.
  static const friendsEmpty = HugeIcons.userGroup;

  /// Solicitudes de amistad recibidas.
  static const friendRequests = HugeIcons.message01;

  /// Persona / amigo en listas.
  static const person = HugeIcons.user;

  /// Perfil propio (apodo y código).
  static const profile = HugeIcons.userSquare;

  /// Apodo / código de amigo.
  static const nickname = HugeIcons.user;

  /// Agregar amigo.
  static const personAdd = HugeIcons.userAdd01;

  /// Botón «Agregar amigo» (por código) en Agregar y buscar.
  static const friendAddButton = HugeIcons.computerAdd;

  /// Quitar amigo.
  static const personRemove = HugeIcons.userRemove01;

  /// Buscar amigo para invitar.
  static const personSearch = HugeIcons.userSearch01;

  /// Sección «Miremos juntos» en Ajustes.
  static const watchParty = HugeIcons.speech;

  /// Interruptor de «Mirar juntos» en Ajustes.
  static const watchPartyToggle = HugeIcons.voice;

  /// Micrófono (mensajes de voz). El de toda la app: `mic02`, la cápsula lisa
  /// con la rayita de base (el `mic01` de este paquete tiene rayas).
  static const mic = HugeIcons.mic02;

  /// Prueba / ajustes de micrófono (la fila de Ajustes).
  static const micSettings = HugeIcons.slidersHorizontal;

  /// Mensajes de voz.
  static const voice = mic;

  /// Grabando.
  static const record = HugeIcons.record;

  /// Detener.
  static const stop = HugeIcons.stop;

  /// Detener (circular).
  static const stopCircle = HugeIcons.stopCircle;

  /// Volumen / reproducir audio.
  static const volume = HugeIcons.volumeHigh;

  /// Consejo / sugerencia.
  static const tip = HugeIcons.bulb;

  // ---------------------------------------------------------------------------
  // 9. Ajustes
  // Consumidores: `features/home/areas/home_settings_area.dart`, `features/settings/`.
  // ---------------------------------------------------------------------------

  // --- 9.1 Configuración de TV (ítems en el orden de pantalla) ---

  /// 1. Mostrar panel de depuración.
  static const debugPanel = HugeIcons.bug01;

  /// Panel de depuración en TV.
  static const debug = HugeIcons.bug01;

  /// 2. Mostrar etiquetas de canales.
  static const channelLabels = HugeIcons.tag01;

  /// 3. Contenido para adultos bloqueado.
  static const lock = HugeIcons.lockPassword;

  /// Contenido para adultos desbloqueado.
  static const lockOpen = HugeIcons.squareUnlock01;

  /// 4. Cambiar PIN parental.
  static const pin = HugeIcons.authorized;

  /// 5. Pestaña de arranque en TV (`settings_tv_startup_tab`).
  static const settingsTvStartupTab = HugeIcons.flag01;

  /// 6. Extensiones - canales (plugins / fuentes).
  static const extension = HugeIcons.puzzle;

  // --- 9.2 Secciones principales y otras opciones de Ajustes ---

  /// Sección «Generales».
  static const settingsGeneral = HugeIcons.slidersHorizontal;

  /// Sección «Películas y series».
  static const settingsMovies = HugeIcons.clapperboard;

  /// TV (sección de TV en Ajustes, amigo mirando un canal).
  static const tv = HugeIcons.modernTv;

  /// Color de acento.
  static const palette = HugeIcons.paintBoard;

  /// Color de acento automático (`accent_color_screen.dart`).
  static const autoAccent = HugeIcons.sparkles;

  /// Tema claro/oscuro.
  static const darkMode = HugeIcons.moon01;

  /// Ajuste de clima.
  static const weather = HugeIcons.sunCloud01;

  /// Calibración de pantalla (overscan).
  static const screenCalibration = HugeIcons.fullScreen;

  /// Sonidos de navegación apagados.
  static const volumeOff = HugeIcons.volumeOff;

  /// Sin extensiones instaladas.
  static const extensionEmpty = HugeIcons.bulb;

  /// Extensión instalada / fuente de canales.
  static const plugin = HugeIcons.blockGame;

  /// Actualizar extensión.
  static const pluginUpdate = HugeIcons.refresh01;

  /// Avisos de la Agenda.
  static const notifications = HugeIcons.bell;

  /// Duración de los avisos.
  static const timer = HugeIcons.timer01;

  /// Zona horaria.
  static const timeZone = HugeIcons.globe;

  /// Actualización de la app.
  static const appUpdate = HugeIcons.downloadSquare02;

  /// Instalación pendiente.
  static const installPending = HugeIcons.download01;

  /// Salir de la app.
  static const exitApp = HugeIcons.logout01;

  /// Dispositivo bloqueado (`blocked_screen.dart`).
  static const blocked = HugeIcons.ban;

  // ---------------------------------------------------------------------------
  // 10. Clima y ubicación
  // Consumidores: `widgets/dialogs/tv_weather_location_dialog.dart`, clima del rail.
  // ---------------------------------------------------------------------------

  /// Clima sin animación disponible.
  static const weatherFallback = HugeIcons.sun01;

  /// Resultado de búsqueda de ubicación.
  static const weatherLocationItem = HugeIcons.location01;

  /// Buscar ubicación.
  static const locationSearch = HugeIcons.search01;

  /// Usar mi ubicación.
  static const myLocation = HugeIcons.location01;

  /// Sin resultados de ubicación / zona.
  static const locationEmpty = HugeIcons.location01;

  // ---------------------------------------------------------------------------
  // 11. Calibración de pantalla
  // Consumidor: `features/bootstrap/screens/overlap_config_screen.dart`.
  // ---------------------------------------------------------------------------

  /// Esquina superior derecha.
  static const northEast = HugeIcons.arrowUpRight01;

  /// Esquina superior izquierda.
  static const northWest = HugeIcons.arrowUpLeft01;

  /// Esquina inferior derecha.
  static const southEast = HugeIcons.arrowDownRight01;

  /// Esquina inferior izquierda.
  static const southWest = HugeIcons.arrowDownLeft01;

  /// Margen horizontal (bordes izquierdo y derecho).
  static const overscanHorizontal = HugeIcons.arrowHorizontal;

  /// Margen vertical (bordes superior e inferior).
  static const overscanVertical = HugeIcons.arrowVertical;

  // ---------------------------------------------------------------------------
  // 12. Acciones y estados comunes
  // ---------------------------------------------------------------------------

  /// Confirmado / seleccionado.
  /// Todos los tildes de la app (confirmar, instalado, éxito, visto, listo)
  /// son el mismo: `strokeRoundedCheckmarkSquare02` (`checkmarkSquare02`).
  static const check = HugeIcons.checkmarkSquare02;

  /// La opción elegida de una lista (zona horaria): el tilde en un cuadrado.
  /// Es el `strokeRoundedSquareCheck` de Hugeicons, que en `hugeicons_plus`
  /// se llama así.
  static const selectedCheck = HugeIcons.checkmarkSquare02;

  /// Única excepción al tilde cuadrado: el color elegido en el selector de
  /// color de acento va con el tilde solo (`strokeRoundedCheck`), dentro del
  /// círculo de color.
  static const colorSelected = HugeIcons.check;

  /// Éxito.
  static const checkCircle = HugeIcons.checkmarkSquare02;

  /// Éxito (relleno/seleccionado).
  static const checkCircleFilled = HugeIcons.checkmarkSquare02;

  /// Error.
  static const error = HugeIcons.alertCircle;

  /// Error (relleno/seleccionado).
  static const errorFilled = HugeIcons.alertCircle;

  /// Advertencia.
  static const warning = HugeIcons.alert01;

  /// Advertencia (relleno/seleccionado).
  static const warningFilled = HugeIcons.alert01;

  /// Información.
  static const info = HugeIcons.informationCircle;

  /// Información (variante circular).
  static const infoCircle = HugeIcons.informationCircle;

  /// Sin conexión.
  static const offline = HugeIcons.wifiDisconnected01;

  /// Borrar.
  static const delete = HugeIcons.delete02;

  /// Reintentar / recargar.
  static const refresh = HugeIcons.refresh;

  /// "Restablecer por defecto" del modal de gamepad.
  static const gamepadReset = HugeIcons.refresh01;

  /// Frecuencia de actualización del catálogo (Ajustes › Películas y series).
  static const catalogFrequency = HugeIcons.cloudSync;

  /// Sincronizar extensión.
  static const sync = HugeIcons.refresh01;

  /// Cerrar.
  static const close = HugeIcons.cancel01;

  /// Limpiar texto.
  static const clear = HugeIcons.cancelCircle;

  /// Buscar.
  static const search = HugeIcons.search01;

  /// Escribir con el teclado en pantalla.
  static const keyboard = HugeIcons.keyboard;

  // ---------------------------------------------------------------------------
  // 13. Flechas
  // ---------------------------------------------------------------------------

  /// Volver.
  static const arrowBack = HugeIcons.arrowLeft01;

  /// Avanzar.
  static const arrowForward = HugeIcons.arrowRight01;

  /// Arriba.
  static const arrowUp = HugeIcons.arrowUp01;

  /// Abajo.
  static const arrowDown = HugeIcons.arrowDown01;

  /// Volver en la cabecera de un panel (`tv_panel_header.dart`).
  static const panelBack = HugeIcons.arrowLeft01;

  /// Semana anterior / ir a la izquierda.
  static const chevronLeft = HugeIcons.chevronLeft;

  /// Semana siguiente / abrir detalle.
  static const chevronRight = HugeIcons.chevronRight;

  /// Hay más contenido arriba en listas y grillas.
  static const chevronUp = HugeIcons.chevronUp;

  /// Hay más contenido abajo en listas y grillas.
  static const chevronDown = HugeIcons.chevronDown;

  // ---------------------------------------------------------------------------
  // 14. Películas y series (VOD)
  // Consumidores: `features/movies/`, `features/home/areas/home_movies_area.dart`.
  // ---------------------------------------------------------------------------

  /// Estado vacío del catálogo de películas (`movies_empty_featured`).
  static const tvMoviesEmpty = HugeIcons.cloudDownload;

  /// Panel Buscar de Películas (columna del acordeón y campo vacío).
  static const moviesSearch = HugeIcons.search01;

  /// Una búsqueda reciente en Buscar de Películas.
  static const moviesSearchRecent = HugeIcons.history;

  /// Resultados del catálogo guardado: el servidor no contestó.
  static const moviesSearchOffline = HugeIcons.wifiDisconnected01;

  /// Tarjeta "Ver todas" al final de cada categoría de la grilla.
  static const moviesShowAll = HugeIcons.popcorn;

  /// Botón "más" (abre el detalle) de la tarjeta destacada.
  static const moviesMore = HugeIcons.moreHorizontal;

  /// Tarjeta: película.
  static const vodMovie = HugeIcons.clapperboard;

  /// Ajustes › Películas y series: borrar películas vistas.
  static const clearWatchedMovies = HugeIcons.clean;

  /// Ajustes › Películas y series: borrar series vistas.
  static const clearWatchedSeries = HugeIcons.bodySoap;

  /// Ajustes › Películas y series: ocultar anime de series.
  static const hideSeriesAnime = HugeIcons.alphabetJapanese;

  /// Tarjeta: tráiler.
  static const vodTrailer = HugeIcons.video01;

  /// Pestaña del detalle de la película.
  static const vodPoster = HugeIcons.clapperboard;

  /// Películas marcadas para ver después: la tarjeta del Inicio y "Marcar"
  /// en la destacada y el detalle.
  static const vodWatchlist = HugeIcons.award04;

  /// "Desmarcar" (ya marcada) y quitarlas de la lista.
  static const vodWatchlistRemove = HugeIcons.badgeMinus;

  /// Descuentos en comercios (tarjeta del Inicio).
  static const discounts = HugeIcons.discountTag02;

  /// Actualizar las promos (encabezado de la semana de Descuentos).
  static const discountRefresh = HugeIcons.refresh04;

  /// Bancos y billeteras del usuario, para los descuentos.
  static const discountBanks = HugeIcons.wallet01;

  /// "Mis comercios" (dónde compra el usuario).
  static const discountMerchants = HugeIcons.store01;

  /// Localidad del usuario (la del clima), en Descuentos.
  static const discountLocation = HugeIcons.location01;

  /// Filtro "Mis comercios / Todos" y de rubro en la semana de descuentos.
  static const discountFilter = HugeIcons.filter;

  /// Rubros de descuentos.
  static const discountRubroSuper = HugeIcons.shoppingCart01;
  static const discountRubroMayoristas = HugeIcons.shippingTruck01;
  static const discountRubroFarmacias = HugeIcons.pill;
  static const discountRubroCombustible = HugeIcons.fuelStation;

  /// Puntaje de la película.
  static const vodRatingFilled = HugeIcons.star;

  /// Fecha de estreno.
  static const vodReleaseDate = HugeIcons.calendar01;

  /// Duración.
  static const vodDuration = HugeIcons.clock01;

  /// Calidad de video.
  static const vodQuality = HugeIcons.hd;

  /// Vista completa.
  static const vodWatched = HugeIcons.checkmarkSquare02;

  /// Continuar viendo.
  static const vodResume = HugeIcons.history;

  /// Buscar hacia adelante (el salto puede ser de cualquier tamaño).
  static const vodSkipForward = HugeIcons.fastForward;

  /// Buscar hacia atrás.
  static const vodSkipBack = HugeIcons.backward01;

  /// Pista de audio.
  static const vodAudio = HugeIcons.volumeHigh;

  /// Subtítulos.
  static const vodSubtitles = HugeIcons.subtitle;

  /// Tamaño de los subtítulos.
  static const vodSubtitleSize = HugeIcons.textFont;

  /// Reproducir.
  static const vodPlay = HugeIcons.play;

  /// Pausa.
  static const vodPause = HugeIcons.pause;

  /// Recomendar una película a los amigos.
  static const vodRecommend = HugeIcons.thumbsUp;

  /// No recomendarla (queda en el TV).
  static const vodNotRecommend = HugeIcons.thumbsDown;

  // ---------------------------------------------------------------------------
  // 15. Teclado en pantalla y PIN
  // Consumidores: `widgets/tv_input/`, `widgets/dialogs/tv_pin/`.
  // ---------------------------------------------------------------------------

  /// Tecla mayúsculas.
  static const keyboardShift = HugeIcons.arrowUpBig;

  /// Tecla borrar.
  static const keyboardBackspace = HugeIcons.cancelSquare;

  /// Borrar dígito del PIN.
  static const pinBackspace = HugeIcons.cancelSquare;

  /// Cerrar el teclado de PIN.
  static const pinClose = HugeIcons.cancel01;

  // ---------------------------------------------------------------------------
  // 16. Arranque
  // Consumidor: `features/loading/screens/loading_screen.dart`.
  // ---------------------------------------------------------------------------

  // Uno distinto por mensaje: así se nota que el arranque avanza.

  /// Verificando el dispositivo.
  static const bootDevice = HugeIcons.modernTv;

  /// Pidiendo el permiso de la VPN.
  static const bootPermission = HugeIcons.key01;

  /// Iniciando los servicios de la VPN.
  static const bootServices = HugeIcons.serverStack01;

  /// Conectando con el servidor de la VPN.
  static const bootServer = HugeIcons.router01;

  /// Conexión segura (VPN).
  static const bootSecure = HugeIcons.securityWifi;

  /// Probando otra conexión.
  static const bootRetry = HugeIcons.reload;

  /// Conexión segura lista.
  static const bootSecureReady = HugeIcons.securityCheck;

  /// Iniciando sesión.
  static const bootSession = HugeIcons.userCheck01;

  /// Sin sesión: películas y series no disponibles.
  static const bootSessionFailed = HugeIcons.userBlock01;

  /// Descargando el catálogo.
  static const bootCatalog = HugeIcons.cloudDownload;

  /// Catálogo actualizado.
  static const bootCatalogUpdated = HugeIcons.cloudSavingDone01;

  /// Catálogo guardado (sin actualizar a propósito).
  static const bootCatalogCached = HugeIcons.database;

  /// No se pudo actualizar el catálogo: queda el guardado.
  static const bootCatalogStale = HugeIcons.databaseRestore;

  /// Cerrando la conexión segura.
  static const bootDisconnect = HugeIcons.unlink02;

  /// Listo.
  static const bootReady = HugeIcons.checkmarkSquare02;
}

/// Escala única de tamaños de íconos (SPEC-50 §4.4).
///
/// Todo `Icon(size: …)` e `iconSize:` de la app usa uno de estos escalones;
/// `test/icons_usage_test.dart` no deja usar números sueltos.
abstract final class MoaiIconSizes {
  MoaiIconSizes._();

  /// Dentro de textos chicos, insignias y etiquetas.
  static const double xs = 12;

  /// Botones chicos, píldoras y filas compactas.
  static const double sm = 16;

  /// Filas de listas y ajustes, botones de acción.
  static const double md = 20;

  /// Botones normales y cabeceras de paneles.
  static const double lg = 24;

  /// Íconos destacados en tarjetas y cabeceras de diálogos.
  static const double xl = 32;

  /// Estados vacíos dentro de paneles.
  static const double xxl = 40;

  /// Estados vacíos y resultados de pantalla completa.
  static const double hero = 48;

  /// Pantallas de bloqueo / error a pantalla completa.
  static const double jumbo = 64;
}
