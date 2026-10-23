import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:reicons/reicons.dart';
import 'package:moai3/utils/text_normalize.dart';

/// Catálogo único de iconos de Moai.
///
/// Cada constante apunta a un [IconData] concreto. El comentario describe
/// en qué zona de la UI se usa (y la ruta del archivo). Cambiar el valor
/// aquí actualiza todos los lugares que referencian la constante.
///
/// Rail: usa [ReiconIcons] / [ReiconFilledIcons] (paquete `reicons`).
/// El resto de la app sigue en Material / Material Symbols salvo que se migre.
abstract final class MoaiIcons {
  MoaiIcons._();

  // ---------------------------------------------------------------------------
  // Rail de navegacion (Reicon — outline idle / filled selected)
  // Buscador: https://reicon.dev/icons
  // ---------------------------------------------------------------------------

  /// Rail Inicio (idle). Origen: `ReiconIcons.home6`
  static const railHome = ReiconIcons.home6;

  /// Rail Inicio (selected). Origen: `ReiconFilledIcons.home6`
  static const railHomeSelected = ReiconFilledIcons.home6;

  /// Rail TV (idle). Origen: `ReiconIcons.tv`
  static const railTv = ReiconIcons.tv;

  /// Rail TV (selected). Origen: `ReiconFilledIcons.tv`
  static const railTvSelected = ReiconFilledIcons.tv;

  /// Rail Destacados (idle). Origen: `ReiconIcons.videoPlayH`
  static const railFeatured = ReiconIcons.videoPlayH;

  /// Rail Destacados (selected). Origen: `ReiconFilledIcons.videoPlayH`
  static const railFeaturedSelected = ReiconFilledIcons.videoPlayH;

  /// Rail Películas (idle). Origen: `ReiconIcons.clapperboardOpen`
  static const railMovies = ReiconIcons.clapperboardOpen;

  /// Rail Películas (selected). Origen: `ReiconFilledIcons.clapperboardOpen`
  static const railMoviesSelected = ReiconFilledIcons.clapperboardOpen;

  /// Rail Series (idle). Origen: `ReiconIcons.videoFrame2`
  static const railSeries = ReiconIcons.videoFrame2;

  /// Rail Series (selected). Origen: `ReiconFilledIcons.videoFrame2`
  static const railSeriesSelected = ReiconFilledIcons.videoFrame2;

  /// Rail Agenda (idle). Origen: `ReiconIcons.calendar`
  static const railCalendar = ReiconIcons.calendar;

  /// Rail Agenda (selected). Origen: `ReiconFilledIcons.calendar`
  static const railCalendarSelected = ReiconFilledIcons.calendar;

  /// Rail Arcade (idle). Origen: `ReiconIcons.gamepad`
  static const railArcade = ReiconIcons.gamepad;

  /// Rail Arcade (selected). Origen: `ReiconFilledIcons.gamepad`
  static const railArcadeSelected = ReiconFilledIcons.gamepad;

  /// Rail Ajustes (idle). Origen: `ReiconIcons.settings`
  static const railSettings = ReiconIcons.gear;

  /// Rail Ajustes (selected). Origen: `ReiconFilledIcons.settings`
  static const railSettingsSelected = ReiconFilledIcons.gear;

  // ---------------------------------------------------------------------------
  // Acordeón Explorar TV (paneles verticales: Grupos / Categorías / Canales)
  // Usado en `_icons()` de `features/home/areas/home_tv_area.dart`.
  // Cambiá solo estas constantes para retocar el acordeón sin afectar empty
  // states ni cabeceras que siguen usando gridViewOutlined / etc.
  // ---------------------------------------------------------------------------

  /// Acordeón «Grupos» (`home_panel_countries` → texto UI "Grupos").
  /// Panel: países/fuentes en el explorador.
  static const tvAccordionGrupos = ReiconIcons.category2;

  /// Acordeón «Categorías» (`home_panel_categories`).
  static const tvAccordionCategorias = ReiconIcons.menuSquare;

  /// Acordeón «Canales» (`home_panel_channels`).
  static const tvAccordionCanales = ReiconIcons.remote;

  /// Acordeón «Inicio» (`home_panel_home_title`).
  static const tvAccordionHome = ReiconIcons.home6;

  /// Acordeón «Destacados» (`movies_panel_featured_title`).
  static const tvAccordionFeatured = ReiconIcons.videoPlayH;

  /// Acordeón «Películas» (`movies_panel_movies_title`).
  static const tvAccordionMovies = ReiconIcons.clapperboardOpen;

  /// Acordeón «Series» (`movies_panel_series_title`).
  static const tvAccordionSeries = ReiconIcons.videoFrame2;

  /// Estado vacío del catálogo de películas (`movies_empty_featured`).
  static const tvMoviesEmpty = ReiconIcons.cloudDownload;

  /// Opción «Pestaña de arranque» en configuración de TV (`settings_tv_startup_tab`).
  static const settingsTvStartupTab = ReiconIcons.flag2;

  // ---------------------------------------------------------------------------
  // Pestañas flotantes TV (Explorar / Buscar / Marcadores)
  // Usado en `features/home/widgets/tv_tab_bar.dart`.
  // Idle = outlined; selected = filled. Cambiá el par sin tocar otros usos.
  // ---------------------------------------------------------------------------

  /// Pestaña «Explorar» idle (`home_tab_explore`). Brújula / compass.
  static const tvTabExplorar = ReiconIcons.compass;

  /// Pestaña «Explorar» selected.
  static const tvTabExplorarSelected = ReiconFilledIcons.compass;

  /// Pestaña «Buscar» idle (`home_tab_search`). Lupa.
  static const tvTabBuscar = ReiconIcons.search4;

  /// Pestaña «Buscar» selected.
  static const tvTabBuscarSelected = ReiconFilledIcons.search4;

  /// Pestaña «Marcadores» idle (`home_tab_groups`). Dos bookmarks.
  static const tvTabMarcadores = ReiconIcons.bookmarks;

  /// Pestaña «Marcadores» selected.
  static const tvTabMarcadoresSelected = ReiconFilledIcons.bookmarks;

  // ---------------------------------------------------------------------------
  // Meta pills del visor de canal (país / categoría / plugin)
  // Usado en `features/home/widgets/tv_viewer_panel.dart`.
  // Ej. UI: [Argentina] [Aire] [ar]
  // ---------------------------------------------------------------------------

  /// Pill país/grupo del canal (ej. "Argentina"). Grilla 2×2.
  static const tvViewerPillCountry = ReiconIcons.category2;

  /// Pill categoría del canal (ej. "Aire"). Formas geométricas.
  static const tvViewerPillCategory = ReiconIcons.menuSquare;

  /// Pill extensión/plugin del canal (ej. "ar"). Pieza de puzzle.
  static const tvViewerPillPlugin = ReiconIcons.puzzle;

  /// Pill canales totales / fuentes en cabecera de extensiones. Enchufe plug2.
  static const tvSourcesTotalChannels = ReiconIcons.plug2;

  /// Icono para campo de URL de extensiones (TvTextField). Link cuadrado.
  static const tvSourcesUrlInput = ReiconIcons.linkSquare;

  /// Icono botón instalar en barra superior de extensiones. Bandeja de entrada (inboxIn).
  static const tvSourcesInstallAction = ReiconIcons.inboxIn;

  // ---------------------------------------------------------------------------
  // Centro de emulación / Arcade en Home
  // ---------------------------------------------------------------------------

  /// 1. Seleccionar juego Arcade (fantasma sonriente)
  static const arcadeActionSelectGame = ReiconIcons.ghostSmile;

  /// 2. Configurar Gamepad Arcade (botones gamepad)
  static const arcadeActionConfigGamepad = ReiconIcons.gamepadButtons;

  /// 3. Iniciar juego Arcade (play3)
  static const arcadeActionStartGame = ReiconIcons.play3;

  /// Refrescar catálogo de ROMs (refreshSquare22 / refreshSquare2)
  static const arcadeCatalogRefresh = ReiconIcons.refreshSquare22;

  /// Ícono de ROM / Juego en catálogo
  static const arcadeRomItem = ReiconIcons.ghostSmile;

  /// Ícono del badge/pill de instalados en cabecera de Arcade (gameboy3)
  static const arcadeRomInstalledBadge = ReiconIcons.gameboy3;

  /// Ícono de la tarjeta de juego instalado (gamepad4)
  static const arcadeRomCard = ReiconIcons.gamepad4;

  /// Eliminar ROM instalada (papelera trash4)
  static const arcadeRomDelete = ReiconIcons.trash4;

  // ---------------------------------------------------------------------------
  // Acciones de favoritos (barra bajo el visor: + / borrar / corazón)
  // create_group_button · clear_favorites_button · favorite_button
  // ---------------------------------------------------------------------------

  /// Crear grupo de marcadores (`CreateGroupButton`). Plus / +.
  static const tvFavoritesAdd = ReiconIcons.plus;

  /// Vaciar favoritos (`ClearFavoritesButton`). Papelera.
  static const tvFavoritesClear = ReiconIcons.trash4;

  /// Icono cabecera modal crear grupo de marcadores (`CreateGroupButton`).
  static const tvGroupCreateDialogTitle = ReiconIcons.bookmark;

  /// Icono campo de texto nombre en modal crear grupo de marcadores (`CreateGroupButton`).
  static const tvGroupCreateDialogInput = ReiconIcons.keyboard;

  /// Icono por defecto de un grupo de marcadores.
  static const tvBookmarkGroupLeading = ReiconIcons.shareCircle;

  /// Clave `ChannelGroup.icon` → icono del grupo.
  static final Map<String, IconData> _groupIcons = {
    'bookmark': tvBookmarkGroupLeading,
    'favorite': favoriteOutline,
    'no_adults': explicitOutlined,
    'sports_soccer': sportsSoccerOutlined,
    'movie': movieOutlined,
    'child_hat': childCareOutlined,
    'newspaper': newspaperOutlined,
    'tv_gen': tvOutlined,
    'language': languageOutlined,
  };

  static IconData groupIconFor(String iconKey) =>
      _groupIcons[iconKey] ?? tvBookmarkGroupLeading;

  /// Toggle favorito idle — no está en favoritos (`FavoriteButton`).
  static const tvFavoritesHeart = ReiconIcons.heart;

  /// Toggle favorito active — canal en favoritos (`FavoriteButton`).
  static const tvFavoritesHeartSelected = ReiconFilledIcons.heart;

  /// Visor vacío de TV sin canal seleccionado o sin canales (`empty_viewer_panel.dart`).
  static const tvEmptyViewer = ReiconIcons.tv;

  // ---------------------------------------------------------------------------
  // Tarjeta de canal — placeholder sin logo
  // Consumidor: `widgets/cards/tv_list_card_leading_logo.dart`
  // ---------------------------------------------------------------------------

  /// Sin logo / logo fallido en la grilla o lista de canales.
  static const tvChannelLogoFallback = ReiconIcons.display;

  /// Estado vacío sin canales (`browser_channels_empty`).
  /// Consumidor: `features/channel_browser/widgets/channel_list_panel.dart`
  static const tvChannelsEmpty = ReiconIcons.magnifierFaceWorried;

  // ---------------------------------------------------------------------------
  // Categorías de canales (panel Categorías)
  // Mapa por nombre exacto del canal. Cambiá el IconData de cada constante.
  // Consumidor: `widgets/cards/category_card.dart` → [tvCategoryIconFor].
  // ---------------------------------------------------------------------------

  /// «Aire» — ondas / aire.
  static const tvCategoryAire = Symbols.airware;

  /// «Interior» / «Provinciales» — ciudad.
  static const tvCategoryInterior = ReiconIcons.city;

  /// «Deportes» — pelota.
  static const tvCategoryDeportes = ReiconIcons.football;

  /// «Noticias» — periódico.
  static const tvCategoryNoticias = Icons.newspaper_outlined;

  /// «Infantiles» / «Infantil» — gorro niño.
  static const tvCategoryInfantiles = Symbols.child_hat;

  /// «Entretenimiento» / «Teleshows» — ticket.
  static const tvCategoryEntretenimiento = Symbols.confirmation_number;

  /// «Comedia» — máscaras teatro.
  static const tvCategoryComedia = Icons.theater_comedy_outlined;

  /// «Reality» — ojo.
  static const tvCategoryReality = Symbols.visibility;

  /// «Anime» — animación.
  static const tvCategoryAnime = Symbols.animation;

  /// «Cocina» — menú / cubiertos.
  static const tvCategoryCocina = ReiconIcons.chefHat;

  /// «Radios» — radio.
  static const tvCategoryRadios = ReiconIcons.radio;

  /// «Series» — TV.
  static const tvCategorySeries = Symbols.tv;

  /// «Películas» / «Cine» / «Cine y Series» — claqueta / movie.
  static const tvCategoryCine = ReiconIcons.clapperboardOpen;

  /// «Documentales» — libros.
  static const tvCategoryDocumentales = Symbols.library_books;

  /// «Música» / «Conciertos» — nota musical.
  static const tvCategoryMusica = ReiconIcons.musicNote;

  /// «Niños» — child care.
  static const tvCategoryNinos = Symbols.child_care;

  /// «Educación» — escuela.
  static const tvCategoryEducacion = Symbols.school;

  /// «Religión» / «Religioso» — iglesia.
  static const tvCategoryReligion = Symbols.church;

  /// «Telenovelas» / «Novelas» — corazón.
  static const tvCategoryNovelas = ReiconIcons.heart2;

  /// «Cultura» / «Cultural» — libro.
  static const tvCategoryCultura = ReiconIcons.book3;

  /// «General» — control remoto.
  static const tvCategoryGeneral = ReiconIcons.remote;

  /// «Otros» — more.
  static const tvCategoryOtros = Symbols.more;

  /// «Internacional» — globo.
  static const tvCategoryInternacional = Symbols.globe;

  /// «Comunitarios» — grupos.
  static const tvCategoryComunitarios = Symbols.groups;

  /// «Culturales» — teatros.
  static const tvCategoryCulturales = Symbols.theaters;

  /// «Adultos» — candado.
  static const tvCategoryAdultos = Symbols.lock;

  /// Fallback si la categoría no está en el mapa.
  static const tvCategoryFallback = Icons.tv_outlined;

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
  // Agenda — suscripciones deportivas + acordeón «Suscripciones»
  // Consumidores: `state/calendar_provider.dart`, `features/home/areas/home_calendar_area.dart`.
  // ---------------------------------------------------------------------------

  /// Acordeón Agenda: panel «Suscripciones» (calendario +).
  static const calendarAccordionSuscripciones = ReiconIcons.calendarAdd;

  /// Suscripción F1 — casco motorsport.
  static const calendarSubF1 = Icons.sports_motorsports_outlined;

  /// Suscripción LPF AR — fútbol.
  static const calendarSubLpf = ReiconIcons.football;

  /// Suscripción Champions League — trofeo.
  static const calendarSubChampions = ReiconIcons.trophy;

  /// Suscripción Premier League — fútbol.
  static const calendarSubPremier = ReiconIcons.football;

  /// Suscripción NFL — fútbol americano (pelota oval / rugby en Reicon).
  static const calendarSubNfl = ReiconIcons.rugby;

  /// Suscripción MotoGP — moto.
  static const calendarSubMotogp = Icons.two_wheeler_outlined;

  /// Suscripción NBA — básquet.
  static const calendarSubNba = ReiconIcons.basketball;

  /// Fallback genérico de deporte / evento sin match.
  static const calendarSubFallback = Icons.sports_outlined;

  /// Mapa id de suscripción → icono (alineado con [CalendarProvider.defaultSubscriptions]).
  static const Map<String, IconData> calendarSubIcons = {
    'f1': calendarSubF1,
    'lpf_ar': calendarSubLpf,
    'champions': calendarSubChampions,
    'premier': calendarSubPremier,
    'nfl': calendarSubNfl,
    'motogp': calendarSubMotogp,
    'nba': calendarSubNba,
  };

  /// Resuelve el icono de una suscripción por id (heurística + [calendarSubFallback]).
  static IconData calendarSubIconFor(String subscriptionId) {
    final exact = calendarSubIcons[subscriptionId];
    if (exact != null) return exact;
    final lower = subscriptionId.toLowerCase();
    if (lower.contains('f1')) return calendarSubF1;
    if (lower.contains('motogp')) return calendarSubMotogp;
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

  // ---------------------------------------------------------------------------
  // Agenda — modal de detalle de evento (`_CalendarEventDialogContent`)
  // Consumidor: `features/calendar/widgets/calendar_events_panel.dart`.
  // ---------------------------------------------------------------------------

  /// Cabecera del modal (título del evento).
  static const calendarDialogTitle = ReiconIcons.calendar;

  /// Tile «Horario».
  static const calendarDialogTime = ReiconIcons.timer2;

  /// Tile «Deporte».
  static const calendarDialogSport = ReiconIcons.football;

  /// Tile «Transmisión».
  static const calendarDialogBroadcast = ReiconIcons.tv;

  // ---------------------------------------------------------------------------
  // Material / Symbols (resto de la UI)
  // ---------------------------------------------------------------------------

  static const tv = Icons.tv;

  static const tvOutlined = Icons.tv_outlined;

  static const calendarMonthOutlined = ReiconIcons.calendarDay;

  static const sportsEsports = Icons.sports_esports;

  static const sportsEsportsOutlined = Icons.sports_esports_outlined;

  static const settings = Icons.settings;

  static const adaptiveAudioMic = ReiconIcons.msgBubbleUser;

  static const airware = Symbols.airware;

  static const animation = Symbols.animation;

  static const arrowBack = Icons.arrow_back;

  static const arrowBackOutlined = ReiconIcons.arrowLeft2;

  static const arrowBackRounded = ReiconIcons.arrowLeft;

  static const arrowDownwardRounded = ReiconIcons.arrowDown;

  static const arrowDropDown = Icons.arrow_drop_down;

  static const arrowDropUp = Icons.arrow_drop_up;

  static const arrowForwardRounded = ReiconIcons.arrowRight;

  static const arrowLeft = Icons.arrow_left;

  static const arrowRight = Icons.arrow_right;

  static const arrowUpwardRounded = ReiconIcons.arrowUp;

  static const aspectRatioOutlined = ReiconIcons.fullscreenSquare;

  static const autoAwesomeOutlined = ReiconIcons.sparkles;

  static const badgeOutlined = ReiconIcons.userId;

  static const block = Icons.block;

  static const bookmarkAddOutlined = Icons.bookmark_add_outlined;

  static const bookmarks = Icons.bookmarks;

  static const browserUpdated = ReiconIcons.desktopDownload;

  static const bugReportOutlined = ReiconIcons.bug;

  static const calendarAddOn = ReiconIcons.calendarAdd;

  static const cancelOutlined = Icons.cancel_outlined;

  static const check = Icons.check;

  static const checkCircle = Symbols.check_circle;

  static const checkCircleOutline = Icons.check_circle_outline;

  static const checkCircleOutlineRounded = ReiconIcons.checkCircle;

  static const checkCircleRounded = Icons.check_circle_rounded;

  static const checkOutlined = ReiconIcons.check;

  static const checkRounded = ReiconIcons.check;

  static const pinBackspace = ReiconIcons.tagCross2;

  static const pinClose = ReiconIcons.x;

  static const installPending = ReiconIcons.squareArrowDown;

  static const chevronLeft = ReiconIcons.chevronLeft;

  static const chevronRight = ReiconIcons.arrowRight2;

  static const childCareOutlined = Icons.child_care_outlined;

  static const church = Symbols.church;

  static const closeOutlined = Icons.close_outlined;

  static const cloudOffOutlined = Icons.cloud_off_outlined;

  static const cloudOutlined = ReiconIcons.cloudSun2;

  static const cloudSyncOutlined = ReiconIcons.globalRefresh2;

  static const darkModeOutlined = ReiconIcons.darkLight;

  static const delete = ReiconIcons.trash4;

  static const deleteOutlineRounded = ReiconIcons.trash4;

  static const deleteSweepOutlined = ReiconIcons.trash4;

  static const dnsOutlined = ReiconIcons.server;

  static const download = Symbols.download;

  static const electricalServices = ReiconIcons.plugCircle;

  static const error = Symbols.error;

  static const errorOutline = Icons.error_outline;

  static const errorOutlineRounded = ReiconIcons.alertCircle;

  static const eventBusyOutlined = Icons.event_busy_outlined;

  static const exitToAppOutlined = ReiconIcons.logout;

  static const explicitOutlined = Icons.explicit_outlined;

  static const explore = Icons.explore;

  static const extension = ReiconIcons.puzzle;

  static const extensionOffOutlined = ReiconIcons.lightbulb3;

  static const extensionOutlined = ReiconIcons.puzzle;

  static const favorite = Icons.favorite;

  static const favoriteOutline = Icons.favorite_outline;

  static const fiberManualRecord = ReiconIcons.record;

  static const gamepad = ReiconIcons.gamepad;

  static const globe = Symbols.globe;

  static const gridViewOutlined = Icons.grid_view_outlined;

  static const groupOffOutlined = ReiconIcons.userX;

  static const groupOutlined = Icons.group_outlined;

  static const groups = Symbols.groups;

  static const host = ReiconIcons.serverUpdate;

  static const info = ReiconIcons.infoCircle;

  static const infoOutline = ReiconIcons.circleInfo;

  static const infoOutlineRounded = Icons.info_outline_rounded;

  static const joystick = ReiconIcons.gamepad;

  static const keyboard = ReiconIcons.keyboard;

  static const keyboardAltOutlined = ReiconIcons.keyboard;

  static const keyboardArrowDown = Icons.keyboard_arrow_down;

  static const keyboardArrowUp = Icons.keyboard_arrow_up;

  static const labelOutline = ReiconIcons.tag2;

  static const languageOutlined = Icons.language_outlined;

  static const lightbulbOutline = ReiconIcons.bulb;

  static const liveTvOutlined = Icons.live_tv_outlined;

  static const locationOffOutlined = Icons.location_off_outlined;

  static const locationOnOutlined = ReiconIcons.pinSearch;

  static const weatherLocationItem = ReiconIcons.mapPoint;

  static const lock = ReiconIcons.lockPassword;

  static const lockOpen = ReiconIcons.lockPasswordOpen;

  static const markEmailReadOutlined = ReiconIcons.deviceMessage2;

  static const mic = ReiconIcons.microphone;

  static const micGear = ReiconIcons.tuning3;

  static const micNoneOutlined = ReiconIcons.microphone;

  static const more = Symbols.more;

  static const movie = Symbols.movie;

  static const movieOutlined = ReiconIcons.clapperboardOpen;

  static const musicNote = Symbols.music_note;

  static const myLocationRounded = ReiconIcons.location2;

  static const newspaperOutlined = Icons.newspaper_outlined;

  static const northEast = ReiconIcons.arrowRightUp;

  static const northWest = ReiconIcons.arrowLeftUp;

  static const notificationsActiveOutlined = ReiconIcons.bell;

  static const paletteOutlined = ReiconIcons.palette2;

  static const peopleAltRounded = ReiconIcons.users;

  static const peopleOutline = ReiconIcons.people2;

  static const peopleOutlineRounded = ReiconIcons.users;

  static const person = ReiconIcons.user;

  static const personAdd = ReiconIcons.userAdd;

  static const personAddAlt1 = Icons.person_add_alt_1;

  static const personAddOutlined = ReiconIcons.userAdd;

  static const personAddRounded = ReiconIcons.userAdd;

  static const personOutline = ReiconIcons.userSquare;

  static const personOutlineRounded = Icons.person_outline_rounded;

  static const personRemoveOutlined = ReiconIcons.userMinus;

  static const personRounded = ReiconIcons.user;

  static const personSearchRounded = Icons.person_search_rounded;

  static const pinOutlined = Icons.pin_outlined;

  static const publicOutlined = ReiconIcons.globe2;

  static const radio = Symbols.radio;

  static const refreshOutlined = ReiconIcons.refresh;

  static const refreshRounded = ReiconIcons.refresh;

  static const school = Symbols.school;

  static const search = Icons.search;

  static const searchOutlined = Icons.search_outlined;

  static const settingsRemote = Icons.settings_remote;

  static const settingsRemoteOutlined = ReiconIcons.tv;

  static const southEast = ReiconIcons.arrowRightDown;

  static const southWest = ReiconIcons.arrowLeftDown;

  static const sportsEsportsRounded = Icons.sports_esports_rounded;

  static const sportsSoccerOutlined = Icons.sports_soccer_outlined;

  static const stop = ReiconIcons.stop;

  static const stopCircleOutlined = ReiconIcons.stopCircle;

  static const stopRounded = ReiconIcons.stop;

  static const symbolSportsEsports = ReiconIcons.gamepad;

  static const syncOutlined = ReiconIcons.refresh;

  static const syncRounded = Icons.sync_rounded;

  static const systemUpdateRounded = Symbols.system_update_rounded;

  static const terminalOutlined = ReiconIcons.searchBug;

  static const theaters = Symbols.theaters;

  static const timerOutlined = ReiconIcons.timer2;

  static const todayOutlined = ReiconIcons.calendarDate;

  static const tuneOutlined = ReiconIcons.tuning;

  static const tvDisplays = ReiconIcons.page;

  static const tvGuide = ReiconIcons.videoLib;

  static const tvRounded = ReiconIcons.tv;

  static const videogameAssetOff = ReiconIcons.gamepad;

  static const videogameAssetOffOutlined = ReiconIcons.gamepad;

  static const visibility = Symbols.visibility;

  static const voiceSelection = ReiconIcons.userSpeak;

  static const volumeUp = ReiconIcons.volumeUp;

  static const volumeUpOutlined = ReiconIcons.volumeUp;

  ///   (`features/settings/widgets/settings_general_panel.dart`)
  static const volumeOffOutlined = ReiconIcons.volumeX;

  static const warning = Symbols.warning;

  static const warningAmber = Symbols.warning_amber;

  static const warningAmberOutlined = Icons.warning_amber_outlined;

  static const warningAmberRounded = ReiconIcons.alertTriangle;

  static const wbSunnyOutlined = Icons.wb_sunny_outlined;

  static const wifiOffRounded = Icons.wifi_off_rounded;

  // VOD (películas y series).
  static const vodMovie = ReiconIcons.videoFrame2;
  static const vodSeries = ReiconIcons.clapperboardText;
  static const vodTrailer = ReiconIcons.reel;
  static const vodPoster = ReiconIcons.clapperboardOpen;
  static const vodRating = ReiconIcons.star;
  static const vodRatingFilled = ReiconFilledIcons.star;
  static const vodReleaseDate = ReiconIcons.calendar;
  static const vodDuration = ReiconIcons.clockCircle;
  static const vodQuality = ReiconIcons.hd;
  static const vodWatched = ReiconFilledIcons.checkCircle;
  static const vodResume = ReiconIcons.history;
  static const vodSkipForward = Icons.forward_10_rounded;
  static const vodSkipBack = Icons.replay_10_rounded;
  static const vodAudio = ReiconIcons.volumeUp;
  static const vodSubtitles = ReiconIcons.text;
  static const vodPlay = ReiconFilledIcons.play;
  static const vodPause = ReiconFilledIcons.pause;

  // Teclado en pantalla.
  static const keyboardShift = ReiconIcons.arrowUp;
  static const keyboardBackspace = ReiconIcons.tagCross2;
}
