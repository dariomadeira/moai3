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
  /// Origen actual: `Icons.grid_view_outlined` (grilla 2×2).
  /// Panel: países/fuentes en el explorador.
  static const tvAccordionGrupos = ReiconIcons.category2;

  /// Acordeón «Categorías» (`home_panel_categories`).
  /// Origen actual: `Icons.category_outlined` (triángulo / cuadrado / círculo).
  static const tvAccordionCategorias = ReiconIcons.menuSquare;

  /// Acordeón «Canales» (`home_panel_channels`).
  /// Origen actual: `Icons.live_tv_outlined` (pantalla con antena + play).
  static const tvAccordionCanales = ReiconIcons.remote;

  /// Acordeón «Inicio» (`home_panel_home_title`).
  /// Origen: `ReiconIcons.home6`
  static const tvAccordionHome = ReiconIcons.home6;

  /// Acordeón «Destacados» (`movies_panel_featured_title`).
  /// Origen: `ReiconIcons.videoPlayH`
  static const tvAccordionFeatured = ReiconIcons.videoPlayH;

  /// Acordeón «Películas» (`movies_panel_movies_title`).
  /// Origen: `ReiconIcons.clapperboardOpen`
  static const tvAccordionMovies = ReiconIcons.clapperboardOpen;

  /// Acordeón «Series» (`movies_panel_series_title`).
  /// Origen: `ReiconIcons.videoFrame2`
  static const tvAccordionSeries = ReiconIcons.videoFrame2;

  /// Estado vacío del catálogo de películas (`movies_empty_featured`).
  /// Origen: `ReiconIcons.cloudDownload`
  static const tvMoviesEmpty = ReiconIcons.cloudDownload;

  /// Opción «Pestaña de arranque» en configuración de TV (`settings_tv_startup_tab`).
  /// Origen: `ReiconIcons.flag2`
  static const settingsTvStartupTab = ReiconIcons.flag2;

  // ---------------------------------------------------------------------------
  // Pestañas flotantes TV (Explorar / Buscar / Marcadores)
  // Usado en `features/home/widgets/tv_tab_bar.dart`.
  // Idle = outlined; selected = filled. Cambiá el par sin tocar otros usos.
  // ---------------------------------------------------------------------------

  /// Pestaña «Explorar» idle (`home_tab_explore`). Brújula / compass.
  /// Origen actual: `Icons.explore_outlined`
  static const tvTabExplorar = ReiconIcons.compass;

  /// Pestaña «Explorar» selected.
  /// Origen actual: `Icons.explore`
  static const tvTabExplorarSelected = ReiconFilledIcons.compass;

  /// Pestaña «Buscar» idle (`home_tab_search`). Lupa.
  /// Origen actual: `Icons.search_outlined`
  static const tvTabBuscar = ReiconIcons.search4;

  /// Pestaña «Buscar» selected.
  /// Origen actual: `Icons.search`
  static const tvTabBuscarSelected = ReiconFilledIcons.search4;

  /// Pestaña «Marcadores» idle (`home_tab_groups`). Dos bookmarks.
  /// Origen actual: `Icons.bookmarks_outlined`
  static const tvTabMarcadores = ReiconIcons.bookmarks;

  /// Pestaña «Marcadores» selected.
  /// Origen actual: `Icons.bookmarks`
  static const tvTabMarcadoresSelected = ReiconFilledIcons.bookmarks;

  // ---------------------------------------------------------------------------
  // Meta pills del visor de canal (país / categoría / plugin)
  // Usado en `features/home/widgets/tv_viewer_panel.dart`.
  // Ej. UI: [Argentina] [Aire] [ar]
  // ---------------------------------------------------------------------------

  /// Pill país/grupo del canal (ej. "Argentina"). Grilla 2×2.
  /// Origen actual: `Icons.grid_view_outlined`
  static const tvViewerPillCountry = ReiconIcons.category2;

  /// Pill categoría del canal (ej. "Aire"). Formas geométricas.
  /// Origen actual: `Icons.category_outlined`
  static const tvViewerPillCategory = ReiconIcons.menuSquare;

  /// Pill extensión/plugin del canal (ej. "ar"). Pieza de puzzle.
  /// Origen actual: `Icons.extension_outlined`
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
  /// Origen actual: `Icons.add_rounded`
  static const tvFavoritesAdd = ReiconIcons.plus;

  /// Vaciar favoritos (`ClearFavoritesButton`). Papelera.
  /// Origen actual: `Icons.delete_outline_rounded` / `ReiconIcons.trash4`
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
  /// Origen actual: `Icons.favorite_outline`
  static const tvFavoritesHeart = ReiconIcons.heart;

  /// Toggle favorito active — canal en favoritos (`FavoriteButton`).
  /// Origen actual: `Icons.favorite`
  static const tvFavoritesHeartSelected = ReiconFilledIcons.heart;

  /// Visor vacío de TV sin canal seleccionado o sin canales (`empty_viewer_panel.dart`).
  static const tvEmptyViewer = ReiconIcons.tv;

  // ---------------------------------------------------------------------------
  // Tarjeta de canal — placeholder sin logo
  // Consumidor: `widgets/cards/tv_list_card_leading_logo.dart`
  // ---------------------------------------------------------------------------

  /// Sin logo / logo fallido en la grilla o lista de canales.
  /// Origen: `ReiconIcons.display`
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
  /// Origen: `ReiconIcons.calendarAdd`
  static const calendarAccordionSuscripciones = ReiconIcons.calendarAdd;

  /// Suscripción F1 — casco motorsport.
  static const calendarSubF1 = Icons.sports_motorsports_outlined;

  /// Suscripción LPF AR — fútbol.
  /// Origen: `ReiconIcons.football`
  static const calendarSubLpf = ReiconIcons.football;

  /// Suscripción Champions League — trofeo.
  static const calendarSubChampions = ReiconIcons.trophy;

  /// Suscripción Premier League — fútbol.
  /// Origen: `ReiconIcons.football`
  static const calendarSubPremier = ReiconIcons.football;

  /// Suscripción NFL — fútbol americano (pelota oval / rugby en Reicon).
  /// Origen: `ReiconIcons.rugby`
  static const calendarSubNfl = ReiconIcons.rugby;

  /// Suscripción MotoGP — moto.
  static const calendarSubMotogp = Icons.two_wheeler_outlined;

  /// Suscripción NBA — básquet.
  /// Origen: `ReiconIcons.basketball`
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
  /// Origen: `ReiconIcons.calendar`
  static const calendarDialogTitle = ReiconIcons.calendar;

  /// Tile «Horario».
  /// Origen: `ReiconIcons.timer2`
  static const calendarDialogTime = ReiconIcons.timer2;

  /// Tile «Deporte».
  /// Origen: `ReiconIcons.football`
  static const calendarDialogSport = ReiconIcons.football;

  /// Tile «Transmisión».
  /// Origen: `ReiconIcons.tv`
  static const calendarDialogBroadcast = ReiconIcons.tv;

  // ---------------------------------------------------------------------------
  // Material / Symbols (resto de la UI)
  // ---------------------------------------------------------------------------

  /// Origen: `Icons.tv`
  static const tv = Icons.tv;

  /// Origen: `Icons.tv_outlined`
  ///
  /// Usos:
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  /// - Placeholder sin logo: ver [tvChannelLogoFallback]
  static const tvOutlined = Icons.tv_outlined;

  /// Origen: `Icons.calendar_month_outlined`
  ///
  /// Usos:
  /// - Agenda (`features/calendar/widgets/calendar_events_panel.dart`)
  /// - Agenda (`features/home/areas/home_calendar_area.dart`)
  /// - Inicio / menú lateral (`features/home/areas/home_settings_area.dart`)
  static const calendarMonthOutlined = ReiconIcons.calendarDay;

  /// Origen: `Icons.sports_esports`
  ///
  /// Usos:
  /// - Arcade (`features/games/screens/arcade_games_screen.dart`)
  /// - Arcade: `arcade_remote_connected_p1` (`features/games/screens/arcade_screen.dart`)
  /// - Inicio: `arcade_invite_received` (`features/home/screens/home_screen.dart`)
  static const sportsEsports = Icons.sports_esports;

  /// Origen: `Icons.sports_esports_outlined`
  ///
  /// Usos:
  /// - Arcade: `arcade_empty_installed_msg` (`features/games/screens/arcade_games_screen.dart`)
  /// - Arcade: `arcade_panel_title` (`features/home/areas/home_arcade_area.dart`)
  static const sportsEsportsOutlined = Icons.sports_esports_outlined;

  /// Origen: `Icons.settings`
  static const settings = Icons.settings;

  /// Origen: `ReiconIcons.msgBubbleUser`
  ///
  /// Usos:
  /// - Inicio / menú lateral (`features/home/areas/home_settings_area.dart`)
  static const adaptiveAudioMic = ReiconIcons.msgBubbleUser;

  /// Origen: `Symbols.airware`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const airware = Symbols.airware;

  /// Origen: `Symbols.animation`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const animation = Symbols.animation;

  /// Origen: `Icons.arrow_back`
  ///
  /// Usos:
  /// - Arcade (`features/games/screens/arcade_screen.dart`)
  static const arrowBack = Icons.arrow_back;

  /// Origen: `ReiconIcons.arrowLeft2`
  ///
  /// Usos:
  /// - Componentes TV compartidos (`widgets/tv_common/tv_panel_header.dart`)
  static const arrowBackOutlined = ReiconIcons.arrowLeft2;

  /// Origen: `ReiconIcons.arrowLeft`
  ///
  /// Usos:
  /// - Arcade (`features/games/screens/arcade_games_screen.dart`)
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  /// - Extensiones (`features/plugins/screens/general_plugins_screen.dart`)
  /// - Extensiones (`features/sources/screens/sources_screen.dart`)
  static const arrowBackRounded = ReiconIcons.arrowLeft;

  /// Origen: `ReiconIcons.arrowDown`
  ///
  /// Usos:
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const arrowDownwardRounded = ReiconIcons.arrowDown;

  /// Origen: `Icons.arrow_drop_down`
  ///
  /// Usos:
  /// - Arcade (`features/games/widgets/arcade_controller_overlay.dart`)
  static const arrowDropDown = Icons.arrow_drop_down;

  /// Origen: `Icons.arrow_drop_up`
  ///
  /// Usos:
  /// - Arcade (`features/games/widgets/arcade_controller_overlay.dart`)
  static const arrowDropUp = Icons.arrow_drop_up;

  /// Origen: `ReiconIcons.arrowRight`
  ///
  /// Usos:
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const arrowForwardRounded = ReiconIcons.arrowRight;

  /// Origen: `Icons.arrow_left`
  ///
  /// Usos:
  /// - Arcade (`features/games/widgets/arcade_controller_overlay.dart`)
  static const arrowLeft = Icons.arrow_left;

  /// Origen: `Icons.arrow_right`
  ///
  /// Usos:
  /// - Arcade (`features/games/widgets/arcade_controller_overlay.dart`)
  static const arrowRight = Icons.arrow_right;

  /// Origen: `ReiconIcons.arrowUp`
  ///
  /// Usos:
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const arrowUpwardRounded = ReiconIcons.arrowUp;

  /// Origen: `ReiconIcons.fullscreenSquare`
  ///
  /// Usos:
  /// - Ajustes: `settings_general_overscan_desc` (`features/settings/widgets/settings_general_panel.dart`)
  /// - Configuración inicial (`features/bootstrap/screens/overlap_config_screen.dart`)
  static const aspectRatioOutlined = ReiconIcons.fullscreenSquare;

  /// Origen: `ReiconIcons.sparkles`
  ///
  /// Usos:
  /// - Ajustes: `settings_general_auto_accent_desc` (`features/settings/widgets/settings_general_panel.dart`)
  static const autoAwesomeOutlined = ReiconIcons.sparkles;

  /// Origen: `ReiconIcons.userId`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_watch_party_code_desc` (`features/settings/widgets/settings_watch_party_panel.dart`)
  /// - Amigos / Ver juntos: `friends_input_label` (`widgets/dialogs/tv_friends_dialog.dart`)
  /// - Amigos / Ver juntos: `nickname_dialog_subtitle_setup` (`widgets/dialogs/tv_nickname_dialog.dart`)
  static const badgeOutlined = ReiconIcons.userId;

  /// Origen: `Icons.block`
  ///
  /// Usos:
  /// - Dispositivo bloqueado (`features/blocked/screens/blocked_screen.dart`)
  static const block = Icons.block;

  /// Origen: `Icons.bookmark_add_outlined`
  ///
  /// Usos:
  /// - Botones compartidos: `groups_create_title` (`widgets/buttons/create_group_button.dart`)
  static const bookmarkAddOutlined = Icons.bookmark_add_outlined;

  /// Origen: `Icons.bookmarks`
  ///
  /// Usos:
  /// - Pestañas TV: ver alias [tvTabMarcadoresSelected]
  static const bookmarks = Icons.bookmarks;

  /// Origen: `ReiconIcons.desktopDownload`
  ///
  /// Usos:
  /// - Actualizaciones: `update_mandatory_title` (`widgets/dialogs/update_dialog.dart`)
  /// - Ajustes: `settings_about_check_updates_desc` (`features/settings/widgets/settings_about_panel.dart`)
  static const browserUpdated = ReiconIcons.desktopDownload;

  /// Origen: `ReiconIcons.bug`
  ///
  /// Usos:
  /// - TV / canales (`features/home/areas/home_tv_area.dart`)
  static const bugReportOutlined = ReiconIcons.bug;

  /// Origen: `Symbols.calendar_add_on`
  ///
  /// Usos:
  /// - Alias agrupado: [calendarAccordionSuscripciones]
  static const calendarAddOn = ReiconIcons.calendarAdd;

  /// Origen: `Icons.cancel_outlined`
  ///
  /// Usos:
  /// - TV / canales (`features/search/widgets/search_panel.dart`)
  static const cancelOutlined = Icons.cancel_outlined;

  /// Origen: `Icons.check`
  ///
  /// Usos:
  /// - Ajustes (`features/settings/screens/agenda_utc_offset_screen.dart`)
  static const check = Icons.check;

  /// Origen: `Symbols.check_circle`
  ///
  /// Usos:
  /// - Actualizaciones (`widgets/dialogs/plugin_update_dialog.dart`)
  static const checkCircle = Symbols.check_circle;

  /// Origen: `Icons.check_circle_outline`
  ///
  /// Usos:
  /// - Ajustes: `nickname_dialog_saved_success` (`features/settings/widgets/settings_watch_party_panel.dart`)
  /// - Amigos / Ver juntos: `friend_add_dialog_success` (`widgets/dialogs/tv_add_friend_dialog.dart`)
  /// - Amigos / Ver juntos: `parental_pin_created_success` (`widgets/dialogs/tv_pin_dialog.dart`)
  /// - Avisos (`helpers/notification_helper.dart`)
  /// - Avisos (`widgets/feedback/moai_snackbar.dart`)
  static const checkCircleOutline = Icons.check_circle_outline;

  /// Origen: `ReiconIcons.checkCircle`
  ///
  /// Usos:
  /// - Arcade (`features/games/screens/arcade_games_screen.dart`)
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  /// - Extensiones (`features/plugins/screens/general_plugins_screen.dart`)
  /// - Extensiones (`features/sources/screens/sources_screen.dart`)
  static const checkCircleOutlineRounded = ReiconIcons.checkCircle;

  /// Origen: `Icons.check_circle_rounded`
  ///
  /// Usos:
  /// - Arcade (`features/games/widgets/tv_arcade_prep_dialog.dart`)
  /// - Clima: `weather_location_configured` (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const checkCircleRounded = Icons.check_circle_rounded;

  /// Origen: `ReiconIcons.check`
  ///
  /// Usos:
  /// - Configuración inicial: `overlap_save` (`features/bootstrap/screens/overlap_config_screen.dart`)
  static const checkOutlined = ReiconIcons.check;

  /// Origen: `ReiconIcons.check`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  /// - Arcade / gamepad: `gamepad_action_close` (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  /// - Clima (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const checkRounded = ReiconIcons.check;

  /// Origen: `ReiconIcons.tagCross2`
  ///
  /// Usos:
  /// - PIN parental: borrar dígito (`widgets/dialogs/tv_pin_dialog.dart`)
  static const pinBackspace = ReiconIcons.tagCross2;

  /// Origen: `ReiconIcons.x`
  ///
  /// Usos:
  /// - PIN parental: cerrar (`widgets/dialogs/tv_pin_dialog.dart`)
  static const pinClose = ReiconIcons.x;

  /// Origen: `ReiconIcons.squareArrowDown`
  ///
  /// Usos:
  /// - Píldora de instalación pendiente (`widgets/buttons/tv_install_pill.dart`)
  static const installPending = ReiconIcons.squareArrowDown;

  /// Origen: `ReiconIcons.chevronLeft`
  ///
  /// Usos:
  /// - Agenda: `calendar_week_nav_prev` (`features/calendar/widgets/calendar_events_panel.dart`)
  static const chevronLeft = ReiconIcons.chevronLeft;

  /// Origen: `ReiconIcons.arrowRight2`
  ///
  /// Usos:
  /// - Agenda: `calendar_week_nav_next` (`features/calendar/widgets/calendar_events_panel.dart`)
  /// - Ajustes (`features/settings/widgets/settings_widgets.dart`)
  static const chevronRight = ReiconIcons.arrowRight2;

  /// Origen: `Icons.child_care_outlined`
  ///
  /// Usos:
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  static const childCareOutlined = Icons.child_care_outlined;

  /// Origen: `Symbols.church`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const church = Symbols.church;

  /// Origen: `Icons.close_outlined`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_pin_dialog.dart`)
  /// - TV / canales (`features/search/widgets/search_panel.dart`)
  static const closeOutlined = Icons.close_outlined;

  /// Origen: `Icons.cloud_off_outlined`
  ///
  /// Usos:
  /// - Ajustes películas: actualizar catálogo apagado
  static const cloudOffOutlined = Icons.cloud_off_outlined;

  /// Origen: `ReiconIcons.cloudSun2`
  ///
  /// Usos:
  /// - Ajustes: `settings_general_weather_title` (`features/settings/widgets/settings_general_panel.dart`)
  static const cloudOutlined = ReiconIcons.cloudSun2;

  /// Origen: `ReiconIcons.globalRefresh2`
  ///
  /// Usos:
  /// - Ajustes películas: actualizar catálogo al arrancar
  static const cloudSyncOutlined = ReiconIcons.globalRefresh2;

  /// Origen: `ReiconIcons.darkLight`
  ///
  /// Usos:
  /// - Ajustes: `settings_general_dark_mode_desc` (`features/settings/widgets/settings_general_panel.dart`)
  static const darkModeOutlined = ReiconIcons.darkLight;

  /// Origen: `Symbols.delete` -> `ReiconIcons.trash4`
  ///
  /// Usos:
  /// - Inicio (`features/home/widgets/alphabet_jump_panel.dart`)
  static const delete = ReiconIcons.trash4;

  /// Origen: `Icons.delete_outline_rounded`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  /// - Arcade (`features/games/screens/arcade_games_screen.dart`)
  /// - Botones compartidos (`widgets/buttons/clear_favorites_button.dart`)
  /// - Extensiones: `plugins_uninstall_tooltip` (`features/plugins/screens/general_plugins_screen.dart`)
  /// - Extensiones: `sources_remove` (`features/sources/screens/sources_screen.dart`)
  static const deleteOutlineRounded = ReiconIcons.trash4;

  /// Origen: `Icons.delete_sweep_outlined`
  ///
  /// Usos:
  /// - Botones compartidos: `favorites_clear_title` (`widgets/buttons/clear_favorites_button.dart`)
  static const deleteSweepOutlined = ReiconIcons.trash4;

  /// Origen: `Icons.dns_outlined` -> `ReiconIcons.server`
  ///
  /// Usos:
  /// - TV / canales: `player_server_n` (`features/home/widgets/tv_viewer_panel.dart`)
  static const dnsOutlined = ReiconIcons.server;

  /// Origen: `Symbols.download`
  ///
  /// Usos:
  /// - Arcade (`features/games/screens/arcade_games_screen.dart`)
  /// - Extensiones (`features/plugins/screens/general_plugins_screen.dart`)
  /// - Extensiones (`features/sources/screens/sources_screen.dart`)
  static const download = Symbols.download;

  /// Origen: `ReiconIcons.plugCircle`
  ///
  /// Usos:
  /// - Actualizaciones (`widgets/dialogs/plugin_update_dialog.dart`)
  /// - Extensiones (`features/plugins/screens/general_plugins_screen.dart`)
  /// - Extensiones (`features/sources/screens/sources_screen.dart`)
  static const electricalServices = ReiconIcons.plugCircle;

  /// Origen: `Symbols.error`
  ///
  /// Usos:
  /// - Actualizaciones (`widgets/dialogs/plugin_update_dialog.dart`)
  /// - Actualizaciones (`widgets/dialogs/update_dialog.dart`)
  static const error = Symbols.error;

  /// Origen: `Icons.error_outline`
  ///
  /// Usos:
  /// - Ajustes: `nickname_dialog_saved_error` (`features/settings/widgets/settings_watch_party_panel.dart`)
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_add_friend_dialog.dart`)
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_pin_dialog.dart`)
  /// - Avisos (`helpers/notification_helper.dart`)
  /// - Avisos (`widgets/feedback/moai_snackbar.dart`)
  /// - Botones compartidos: `groups_create_error` (`widgets/buttons/create_group_button.dart`)
  /// - Reproductor (`widgets/player/viewer_error_display.dart`)
  static const errorOutline = Icons.error_outline;

  /// Origen: `ReiconIcons.alertCircle`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  /// - Extensiones (`features/sources/screens/sources_screen.dart`)
  static const errorOutlineRounded = ReiconIcons.alertCircle;

  /// Origen: `Icons.event_busy_outlined`
  ///
  /// Usos:
  /// - Agenda (`features/calendar/widgets/calendar_events_panel.dart`)
  static const eventBusyOutlined = Icons.event_busy_outlined;

  /// Origen: `ReiconIcons.logout`
  ///
  /// Usos:
  /// - Inicio: `home_exit_double_back` (`features/home/widgets/double_back_exit_scope.dart`)
  static const exitToAppOutlined = ReiconIcons.logout;

  /// Origen: `Icons.explicit_outlined`
  ///
  /// Usos:
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  static const explicitOutlined = Icons.explicit_outlined;

  /// Origen: `Icons.explore`
  ///
  /// Usos:
  /// - Pestañas TV: ver alias [tvTabExplorarSelected]
  static const explore = Icons.explore;

  /// Origen: `ReiconIcons.puzzle`
  ///
  /// Usos:
  /// - Actualizaciones: `plugin_update_title_singular` (`widgets/dialogs/plugin_update_dialog.dart`)
  /// - Ajustes: `settings_general_sources_desc` (`features/settings/widgets/settings_tv_panel.dart`)
  /// - Extensiones (`features/plugins/screens/general_plugins_screen.dart`)
  /// - Extensiones (`features/sources/screens/sources_screen.dart`)
  static const extension = ReiconIcons.puzzle;

  /// Origen: `ReiconIcons.lightbulb3`
  ///
  /// Usos:
  /// - Extensiones: `plugins_empty_installed_msg` (`features/plugins/screens/general_plugins_screen.dart`)
  /// - Extensiones: `sources_empty` (`features/sources/screens/sources_screen.dart`)
  static const extensionOffOutlined = ReiconIcons.lightbulb3;

  /// Origen: `ReiconIcons.puzzle`
  ///
  /// Usos:
  /// - Ajustes: `settings_general_plugins_title` (`features/settings/widgets/settings_general_panel.dart`)
  /// - Visor canal: ver alias [tvViewerPillPlugin]
  static const extensionOutlined = ReiconIcons.puzzle;

  /// Origen: `Icons.favorite`
  ///
  /// Usos:
  /// - Favoritos barra: ver alias [tvFavoritesHeartSelected]
  static const favorite = Icons.favorite;

  /// Origen: `Icons.favorite_outline`
  ///
  /// Usos:
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  /// - Favoritos barra: ver alias [tvFavoritesHeart]
  static const favoriteOutline = Icons.favorite_outline;

  /// Origen: `ReiconIcons.record`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `mic_test_btn_record` (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const fiberManualRecord = ReiconIcons.record;

  /// Origen: `ReiconIcons.gamepad`
  ///
  /// Usos:
  /// - Arcade: `arcade_gamepad_config_title` (`features/home/areas/home_arcade_area.dart`)
  /// - Arcade / gamepad: `gamepad_detected_section_header` (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const gamepad = ReiconIcons.gamepad;

  /// Origen: `Symbols.globe`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const globe = Symbols.globe;

  /// Origen: `Icons.grid_view_outlined`
  ///
  /// Usos:
  /// - TV / canales: `browser_countries_empty` (`features/channel_browser/widgets/country_list_panel.dart`)
  /// - Acordeón Explorar: ver alias [tvAccordionGrupos]
  /// - Visor canal: ver alias [tvViewerPillCountry]
  static const gridViewOutlined = Icons.grid_view_outlined;

  /// Origen: `ReiconIcons.userX`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  /// - Arcade (`features/games/widgets/tv_arcade_select_friend_dialog.dart`)
  static const groupOffOutlined = ReiconIcons.userX;

  /// Origen: `Icons.group_outlined`
  ///
  /// Usos:
  /// - Arcade: `arcade_action_play_together_desc` (`features/home/areas/home_arcade_area.dart`)
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  static const groupOutlined = Icons.group_outlined;

  /// Origen: `Symbols.groups`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const groups = Symbols.groups;

  /// Origen: `Symbols.host` -> `ReiconIcons.serverUpdate`
  ///
  /// Usos:
  /// - Botones compartidos (`widgets/buttons/server_skip_button.dart`)
  static const host = ReiconIcons.serverUpdate;

  /// Origen: `ReiconIcons.infoCircle`
  ///
  /// Usos:
  /// - Arcade / gamepad: `gamepad_support_two_players` (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const info = ReiconIcons.infoCircle;

  /// Origen: `ReiconIcons.circleInfo`
  ///
  /// Usos:
  /// - Arcade: `arcade_no_game_installed_snack` (`features/home/areas/home_arcade_area.dart`)
  /// - Avisos (`helpers/notification_helper.dart`)
  /// - Avisos (`widgets/feedback/moai_snackbar.dart`)
  /// - Inicio: `arcade_no_game_installed_snack` (`features/home/screens/home_screen.dart`)
  /// - Inicio / menú lateral (`features/home/areas/home_settings_area.dart`)
  static const infoOutline = ReiconIcons.circleInfo;

  /// Origen: `Icons.info_outline_rounded`
  ///
  /// Usos:
  /// - Arcade (`features/games/widgets/tv_arcade_prep_dialog.dart`)
  /// - Clima (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const infoOutlineRounded = Icons.info_outline_rounded;

  /// Origen: `ReiconIcons.gamepad`
  ///
  /// Usos:
  /// - Arcade (`features/games/screens/arcade_games_screen.dart`)
  /// - Arcade: `arcade_action_select_game` (`features/home/areas/home_arcade_area.dart`)
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const joystick = ReiconIcons.gamepad;

  /// Origen: `Icons.keyboard`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_add_friend_dialog.dart`)
  static const keyboard = ReiconIcons.keyboard;

  /// Origen: `Icons.keyboard_alt_outlined`
  ///
  /// Usos:
  /// - Componentes TV compartidos (`widgets/tv_input/tv_text_field.dart`)
  /// - TV / canales: `search_field_label` (`features/search/widgets/search_panel.dart`)
  static const keyboardAltOutlined = ReiconIcons.keyboard;

  /// Origen: `Icons.keyboard_arrow_down`
  ///
  /// Usos:
  /// - Agenda (`features/calendar/widgets/calendar_events_panel.dart`)
  /// - Listas TV (indicador de scroll) (`widgets/lists/tv_windowed_grid.dart`)
  /// - Listas TV (indicador de scroll) (`widgets/lists/tv_windowed_list.dart`)
  static const keyboardArrowDown = Icons.keyboard_arrow_down;

  /// Origen: `Icons.keyboard_arrow_up`
  ///
  /// Usos:
  /// - Agenda (`features/calendar/widgets/calendar_events_panel.dart`)
  /// - Listas TV (indicador de scroll) (`widgets/lists/tv_windowed_grid.dart`)
  /// - Listas TV (indicador de scroll) (`widgets/lists/tv_windowed_list.dart`)
  static const keyboardArrowUp = Icons.keyboard_arrow_up;

  /// Origen: `ReiconIcons.tag2`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_channel_labels_desc` (`features/settings/widgets/settings_tv_panel.dart`)
  static const labelOutline = ReiconIcons.tag2;

  /// Origen: `Icons.language_outlined`
  ///
  /// Usos:
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  static const languageOutlined = Icons.language_outlined;

  /// Origen: `ReiconIcons.bulb`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const lightbulbOutline = ReiconIcons.bulb;

  /// Origen: `Icons.live_tv_outlined`
  ///
  /// Usos:
  /// - Agenda (`state/calendar_provider.dart`)
  /// - TV / canales (`features/home/widgets/empty_viewer_panel.dart`)
  /// - Acordeón Explorar: ver alias [tvAccordionCanales]
  static const liveTvOutlined = Icons.live_tv_outlined;

  /// Origen: `Icons.location_off_outlined`
  ///
  /// Usos:
  /// - Clima (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const locationOffOutlined = Icons.location_off_outlined;

  /// Origen: `ReiconIcons.pinSearch`
  ///
  /// Usos:
  /// - Clima: `weather_location_dialog_title` (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const locationOnOutlined = ReiconIcons.pinSearch;

  /// Origen: `ReiconIcons.mapPoint`
  ///
  /// Usos:
  /// - Clima: ítems de localidad sugerida (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const weatherLocationItem = ReiconIcons.mapPoint;

  /// Origen: `ReiconIcons.lockPassword`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_adult_content_desc` (`features/settings/widgets/settings_tv_panel.dart`)
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_pin_dialog.dart`)
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const lock = ReiconIcons.lockPassword;

  /// Origen: `ReiconIcons.lockPasswordOpen`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_adult_content_desc` (`features/settings/widgets/settings_tv_panel.dart`)
  /// - Amigos / Ver juntos: `parental_adult_unlocked` (`widgets/dialogs/tv_pin_dialog.dart`)
  static const lockOpen = ReiconIcons.lockPasswordOpen;

  /// Origen: `ReiconIcons.deviceMessage2`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  static const markEmailReadOutlined = ReiconIcons.deviceMessage2;

  /// Origen: `ReiconIcons.microphone`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/player/watch_party_overlay.dart`)
  /// - Inicio (`features/home/widgets/tv_watch_party_header_bar.dart`)
  static const mic = ReiconIcons.microphone;

  /// Origen: `ReiconIcons.tuning3`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_mic_test_desc` (`features/settings/widgets/settings_watch_party_panel.dart`)
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const micGear = ReiconIcons.tuning3;

  /// Origen: `ReiconIcons.microphone`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const micNoneOutlined = ReiconIcons.microphone;

  /// Origen: `Symbols.more`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const more = Symbols.more;

  /// Origen: `Symbols.movie`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  /// - Inicio / menú lateral: `home_rail_movies_title` (`features/home/widgets/tv_vertical_nav_rail.dart`)
  /// - Tarjeta de película (`features/home/widgets/tv_movie_card.dart`)
  static const movie = Symbols.movie;

  /// Origen: `ReiconIcons.clapperboardOpen`
  ///
  /// Usos:
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  /// - Inicio / menú lateral: `home_rail_movies_title` (`features/home/widgets/tv_vertical_nav_rail.dart`)
  /// - Área películas (`features/home/areas/home_movies_area.dart`)
  static const movieOutlined = ReiconIcons.clapperboardOpen;

  /// Origen: `Symbols.music_note`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const musicNote = Symbols.music_note;

  /// Origen: `ReiconIcons.location2`
  ///
  /// Usos:
  /// - Clima: `weather_location_reset_auto` (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const myLocationRounded = ReiconIcons.location2;

  /// Origen: `Icons.newspaper_outlined`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  static const newspaperOutlined = Icons.newspaper_outlined;

  /// Origen: `ReiconIcons.arrowRightUp`
  ///
  /// Usos:
  /// - Configuración inicial (`features/bootstrap/screens/overlap_config_screen.dart`)
  static const northEast = ReiconIcons.arrowRightUp;

  /// Origen: `ReiconIcons.arrowLeftUp`
  ///
  /// Usos:
  /// - Configuración inicial (`features/bootstrap/screens/overlap_config_screen.dart`)
  static const northWest = ReiconIcons.arrowLeftUp;

  /// Origen: `ReiconIcons.bell`
  ///
  /// Usos:
  /// - Ajustes: `settings_agenda_notify_desc` (`features/settings/widgets/settings_agenda_notify_row.dart`)
  static const notificationsActiveOutlined = ReiconIcons.bell;

  /// Origen: `ReiconIcons.palette2`
  ///
  /// Usos:
  /// - Ajustes (`features/settings/widgets/settings_general_panel.dart`)
  static const paletteOutlined = ReiconIcons.palette2;

  /// Origen: `ReiconIcons.users`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `friends_screen_title` (`widgets/dialogs/tv_friends_dialog.dart`)
  static const peopleAltRounded = ReiconIcons.users;

  /// Origen: `ReiconIcons.people2`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_manage_friends` (`features/settings/widgets/settings_watch_party_panel.dart`)
  static const peopleOutline = ReiconIcons.people2;

  /// Origen: `ReiconIcons.users`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `friends_section_friends` (`widgets/dialogs/tv_friends_dialog.dart`)
  static const peopleOutlineRounded = ReiconIcons.users;

  /// Origen: `ReiconIcons.user`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/player/watch_party_overlay.dart`)
  /// - TV / canales: `watch_party_friend_joined` (`features/home/areas/home_tv_area.dart`)
  static const person = ReiconIcons.user;

  /// Origen: `ReiconIcons.userAdd`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `friends_add_button` (`widgets/dialogs/tv_friends_dialog.dart`)
  static const personAdd = ReiconIcons.userAdd;

  /// Origen: `Icons.person_add_alt_1`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `friend_add_dialog_title` (`widgets/dialogs/tv_add_friend_dialog.dart`)
  static const personAddAlt1 = Icons.person_add_alt_1;

  /// Origen: `ReiconIcons.userAdd`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `friends_section_requests` (`widgets/dialogs/tv_friends_dialog.dart`)
  static const personAddOutlined = ReiconIcons.userAdd;

  /// Origen: `ReiconIcons.userAdd`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  static const personAddRounded = ReiconIcons.userAdd;

  /// Origen: `ReiconIcons.userSquare`
  ///
  /// Usos:
  /// - Ajustes: `settings_watch_party_nickname_desc` (`features/settings/widgets/settings_watch_party_panel.dart`)
  /// - Amigos / Ver juntos: `nickname_dialog_label` (`widgets/dialogs/tv_nickname_dialog.dart`)
  static const personOutline = ReiconIcons.userSquare;

  /// Origen: `Icons.person_outline_rounded`
  ///
  /// Usos:
  /// - Arcade: `friends_status_online` (`features/games/widgets/tv_arcade_select_friend_dialog.dart`)
  static const personOutlineRounded = Icons.person_outline_rounded;

  /// Origen: `ReiconIcons.userMinus`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `friends_delete_confirm_title` (`widgets/dialogs/tv_friends_dialog.dart`)
  static const personRemoveOutlined = ReiconIcons.userMinus;

  /// Origen: `ReiconIcons.user`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  static const personRounded = ReiconIcons.user;

  /// Origen: `Icons.person_search_rounded`
  ///
  /// Usos:
  /// - Arcade: `arcade_select_friend_title` (`features/games/widgets/tv_arcade_select_friend_dialog.dart`)
  static const personSearchRounded = Icons.person_search_rounded;

  /// Origen: `Icons.pin_outlined`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_change_pin_desc` (`features/settings/widgets/settings_tv_panel.dart`)
  static const pinOutlined = Icons.pin_outlined;

  /// Origen: `ReiconIcons.globe2`
  ///
  /// Usos:
  /// - Ajustes (`features/settings/screens/agenda_utc_offset_screen.dart`)
  /// - Ajustes: `settings_agenda_utc_desc` (`features/settings/widgets/settings_agenda_panel.dart`)
  static const publicOutlined = ReiconIcons.globe2;

  /// Origen: `Symbols.radio`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const radio = Symbols.radio;

  /// Origen: `ReiconIcons.refresh`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `mic_test_btn_rerecord` (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const refreshOutlined = ReiconIcons.refresh;

  /// Origen: `ReiconIcons.refresh`
  ///
  /// Usos:
  /// - Arcade: `arcade_btn_refresh` (`features/games/screens/arcade_games_screen.dart`)
  /// - Arcade / gamepad: `gamepad_action_reset` (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  /// - Pantalla de carga: `update_action_retry` (`features/loading/screens/loading_screen.dart`)
  static const refreshRounded = ReiconIcons.refresh;

  /// Origen: `Symbols.school`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const school = Symbols.school;

  /// Origen: `Icons.search`
  ///
  /// Usos:
  /// - Pestañas TV: ver alias [tvTabBuscarSelected]
  static const search = Icons.search;

  /// Origen: `Icons.search_outlined`
  ///
  /// Usos:
  /// - Pestañas TV: ver alias [tvTabBuscar]
  static const searchOutlined = Icons.search_outlined;

  /// Origen: `Icons.settings_remote`
  ///
  /// Usos:
  /// - Arcade: `arcade_remote_connected_p1` (`features/games/screens/arcade_screen.dart`)
  static const settingsRemote = Icons.settings_remote;

  /// Origen: `ReiconIcons.tv`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_voice_test_dialog.dart`)
  /// - Inicio / menú lateral (`features/home/areas/home_settings_area.dart`)
  static const settingsRemoteOutlined = ReiconIcons.tv;

  /// Origen: `ReiconIcons.arrowRightDown`
  ///
  /// Usos:
  /// - Configuración inicial (`features/bootstrap/screens/overlap_config_screen.dart`)
  static const southEast = ReiconIcons.arrowRightDown;

  /// Origen: `ReiconIcons.arrowLeftDown`
  ///
  /// Usos:
  /// - Configuración inicial (`features/bootstrap/screens/overlap_config_screen.dart`)
  static const southWest = ReiconIcons.arrowLeftDown;

  /// Origen: `Icons.sports_esports_rounded`
  ///
  /// Usos:
  /// - Arcade: `arcade_prep_title` (`features/games/widgets/tv_arcade_prep_dialog.dart`)
  /// - Arcade (`features/games/widgets/tv_arcade_select_friend_dialog.dart`)
  static const sportsEsportsRounded = Icons.sports_esports_rounded;

  /// Origen: `Icons.sports_soccer_outlined`
  ///
  /// Usos:
  /// - Alias agrupado: [calendarSubLpf] / [calendarSubPremier]
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  static const sportsSoccerOutlined = Icons.sports_soccer_outlined;

  /// Origen: `ReiconIcons.stop`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `mic_test_btn_stop_play` (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const stop = ReiconIcons.stop;

  /// Origen: `ReiconIcons.stopCircle`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `mic_test_btn_stop` (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const stopCircleOutlined = ReiconIcons.stopCircle;

  /// Origen: `ReiconIcons.stop`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/player/watch_party_overlay.dart`)
  /// - Inicio (`features/home/widgets/tv_watch_party_header_bar.dart`)
  static const stopRounded = ReiconIcons.stop;

  /// Origen: `ReiconIcons.gamepad`
  ///
  /// Usos:
  /// - Arcade / gamepad: `gamepad_dialog_title` (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const symbolSportsEsports = ReiconIcons.gamepad;

  /// Origen: `ReiconIcons.refresh`
  ///
  /// Usos:
  /// - Agenda: `calendar_refresh` (`features/calendar/widgets/calendar_events_panel.dart`)
  static const syncOutlined = ReiconIcons.refresh;

  /// Origen: `Icons.sync_rounded`
  ///
  /// Usos:
  /// - Extensiones: `plugins_reinstall_tooltip` (`features/plugins/screens/general_plugins_screen.dart`)
  /// - Extensiones: `sources_update` (`features/sources/screens/sources_screen.dart`)
  static const syncRounded = Icons.sync_rounded;

  /// Origen: `Symbols.system_update_rounded`
  ///
  /// Usos:
  /// - Extensiones: `sources_update_to_version` (`features/sources/screens/sources_screen.dart`)
  static const systemUpdateRounded = Symbols.system_update_rounded;

  /// Origen: `ReiconIcons.searchBug`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_log_desc` (`features/settings/widgets/settings_tv_panel.dart`)
  static const terminalOutlined = ReiconIcons.searchBug;

  /// Origen: `Symbols.theaters`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const theaters = Symbols.theaters;

  /// Origen: `ReiconIcons.timer2`
  ///
  /// Usos:
  /// - Ajustes: `settings_agenda_snack_duration_desc` (`features/settings/widgets/settings_agenda_snack_duration_row.dart`)
  static const timerOutlined = ReiconIcons.timer2;

  /// Origen: `ReiconIcons.calendarDate`
  ///
  /// Usos:
  /// - Agenda: `calendar_week_current` (`features/calendar/widgets/calendar_events_panel.dart`)
  static const todayOutlined = ReiconIcons.calendarDate;

  /// Origen: `ReiconIcons.tuning`
  ///
  /// Usos:
  /// - Inicio / menú lateral (`features/home/areas/home_settings_area.dart`)
  static const tuneOutlined = ReiconIcons.tuning;

  /// Origen: `Symbols.tv_displays`
  ///
  /// Usos:
  /// - TV / canales: listado de países (`widgets/cards/country_card.dart`)
  static const tvDisplays = ReiconIcons.page;

  /// Origen: `ReiconIcons.videoLib`
  ///
  /// Usos:
  /// - Ajustes: `settings_about_channels_loaded` (`features/settings/widgets/settings_about_panel.dart`)
  static const tvGuide = ReiconIcons.videoLib;

  /// Origen: `ReiconIcons.tv`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  static const tvRounded = ReiconIcons.tv;

  /// Origen: `ReiconIcons.gamepad`
  ///
  /// Usos:
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const videogameAssetOff = ReiconIcons.gamepad;

  /// Origen: `ReiconIcons.gamepad`
  ///
  /// Usos:
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const videogameAssetOffOutlined = ReiconIcons.gamepad;

  /// Origen: `Symbols.visibility`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const visibility = Symbols.visibility;

  /// Origen: `ReiconIcons.userSpeak`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_watch_party_desc` (`features/settings/widgets/settings_watch_party_panel.dart`)
  /// - Amigos / Ver juntos (`widgets/player/watch_party_overlay.dart`)
  /// - Inicio (`features/home/widgets/tv_watch_party_header_bar.dart`)
  static const voiceSelection = ReiconIcons.userSpeak;

  /// Origen: `ReiconIcons.volumeUp`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const volumeUp = ReiconIcons.volumeUp;

  /// Origen: `ReiconIcons.volumeUp`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `mic_test_btn_stop_play` (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const volumeUpOutlined = ReiconIcons.volumeUp;

  /// Origen: `ReiconIcons.volumeX`
  ///
  /// Usos:
  /// - Ajustes Generales: desactivar audio de interfaz
  ///   (`features/settings/widgets/settings_general_panel.dart`)
  static const volumeOffOutlined = ReiconIcons.volumeX;

  /// Origen: `Symbols.warning`
  ///
  /// Usos:
  /// - Actualizaciones: `update_mandatory_notice` (`widgets/dialogs/update_dialog.dart`)
  static const warning = Symbols.warning;

  /// Origen: `Symbols.warning_amber`
  ///
  /// Usos:
  /// - Actualizaciones: `update_mandatory_title` (`widgets/dialogs/update_dialog.dart`)
  static const warningAmber = Symbols.warning_amber;

  /// Origen: `Icons.warning_amber_outlined`
  ///
  /// Usos:
  /// - Avisos (`helpers/notification_helper.dart`)
  /// - Avisos (`widgets/feedback/moai_snackbar.dart`)
  static const warningAmberOutlined = Icons.warning_amber_outlined;

  /// Origen: `ReiconIcons.alertTriangle`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `mic_test_empty_desc` (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const warningAmberRounded = ReiconIcons.alertTriangle;

  /// Origen: `Icons.wb_sunny_outlined`
  ///
  /// Usos:
  /// - Inicio (`features/home/widgets/tv_weather_animated_icon.dart`)
  static const wbSunnyOutlined = Icons.wb_sunny_outlined;

  /// Origen: `Icons.wifi_off_rounded`
  ///
  /// Usos:
  /// - Pantalla de carga: `loading_error_title` (`features/loading/screens/loading_screen.dart`)
  static const wifiOffRounded = Icons.wifi_off_rounded;
}
