import 'package:flutter/widgets.dart';
import 'package:reicons/reicons.dart';
import 'package:moai3/utils/text_normalize.dart';

/// Catálogo único de íconos de Moai (SPEC-50 §4).
///
/// Toda la app usa estas constantes; nadie más importa paquetes de íconos
/// (`test/icons_usage_test.dart`). Familia única: Reicon
/// (https://reicon.dev/icons): contorno [ReiconIcons], relleno
/// [ReiconFilledIcons]. Cambiar un valor acá cambia todos sus usos.
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
///
/// Tamaños: usar siempre [MoaiIconSizes], nunca un número suelto.
abstract final class MoaiIcons {
  MoaiIcons._();

  // ---------------------------------------------------------------------------
  // Navegación — rail lateral
  // Consumidor: `features/home/widgets/tv_vertical_nav_rail.dart`.
  // Idle = contorno, seleccionado = relleno.
  // ---------------------------------------------------------------------------

  /// Rail «Inicio» (sin seleccionar).
  static const railHome = ReiconIcons.home6;

  /// Rail «Inicio» (seleccionado).
  static const railHomeSelected = ReiconFilledIcons.home6;

  /// Rail «TV» (sin seleccionar).
  static const railTv = ReiconIcons.tv;

  /// Rail «TV» (seleccionado).
  static const railTvSelected = ReiconFilledIcons.tv;

  /// Rail «Destacados» (sin seleccionar).
  static const railFeatured = ReiconIcons.videoPlayH;

  /// Rail «Destacados» (seleccionado).
  static const railFeaturedSelected = ReiconFilledIcons.videoPlayH;

  /// Rail «Películas» (sin seleccionar).
  static const railMovies = ReiconIcons.clapperboardOpen;

  /// Rail «Películas» (seleccionado).
  static const railMoviesSelected = ReiconFilledIcons.clapperboardOpen;

  /// Rail «Series» (sin seleccionar).
  static const railSeries = ReiconIcons.videoFrame2;

  /// Rail «Series» (seleccionado).
  static const railSeriesSelected = ReiconFilledIcons.videoFrame2;

  /// Rail «Agenda» (sin seleccionar).
  static const railCalendar = ReiconIcons.calendar;

  /// Rail «Agenda» (seleccionado).
  static const railCalendarSelected = ReiconFilledIcons.calendar;

  /// Rail «Descuentos» (sin seleccionar / seleccionado).
  static const railDiscounts = ReiconIcons.percentTag;
  static const railDiscountsSelected = ReiconFilledIcons.percentTag;

  /// Rail «Arcade» (sin seleccionar).
  static const railArcade = ReiconIcons.gamepad;

  /// Rail «Arcade» (seleccionado).
  static const railArcadeSelected = ReiconFilledIcons.gamepad;

  /// Rail «Ajustes» (sin seleccionar).
  static const railSettings = ReiconIcons.gear;

  /// Rail «Ajustes» (seleccionado).
  static const railSettingsSelected = ReiconFilledIcons.gear;

  // ---------------------------------------------------------------------------
  // TV — acordeón de paneles y pestañas
  // Consumidores: `features/home/areas/`, `features/home/widgets/tv_tab_bar.dart`.
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
  // TV — visor, canales y extensiones
  // ---------------------------------------------------------------------------

  /// Pill país/grupo del canal (ej. "Argentina"). Grilla 2×2.
  static const tvViewerPillCountry = ReiconIcons.category2;

  /// Pill categoría del canal (ej. "Aire"). Formas geométricas.
  static const tvViewerPillCategory = ReiconIcons.menuSquare;

  /// Pill extensión/plugin del canal (ej. "ar"). Pieza de puzzle.
  static const tvViewerPillPlugin = ReiconIcons.puzzle;

  /// Visor vacío de TV sin canal seleccionado o sin canales (`empty_viewer_panel.dart`).
  static const tvEmptyViewer = ReiconIcons.tv;

  /// Sin logo / logo fallido en la grilla o lista de canales.
  static const tvChannelLogoFallback = ReiconIcons.display;

  /// Estado vacío sin canales (`browser_channels_empty`).
  /// Consumidor: `features/channel_browser/widgets/channel_list_panel.dart`
  static const tvChannelsEmpty = ReiconIcons.magnifierFaceWorried;

  /// Pill canales totales / fuentes en cabecera de extensiones. Enchufe plug2.
  static const tvSourcesTotalChannels = ReiconIcons.plug2;

  /// Icono para campo de URL de extensiones (TvTextField). Link cuadrado.
  static const tvSourcesUrlInput = ReiconIcons.linkSquare;

  /// Icono botón instalar en barra superior de extensiones. Bandeja de entrada (inboxIn).
  static const tvSourcesInstallAction = ReiconIcons.inboxIn;

  /// Ítem de país/grupo en el panel Grupos (`country_list_panel.dart`).
  static const tvCountryItem = ReiconIcons.page;

  /// Servidor actual del canal en el visor (`tv_viewer_panel.dart`).
  static const server = ReiconIcons.server;

  /// Botón «saltar servidor» (`server_skip_button.dart`).
  static const serverSkip = ReiconIcons.serverUpdate;

  // ---------------------------------------------------------------------------
  // TV — favoritos y grupos (marcadores)
  // ---------------------------------------------------------------------------

  /// Crear grupo de marcadores (`CreateGroupButton`). Plus / +.
  static const tvFavoritesAdd = ReiconIcons.plus;

  /// Vaciar favoritos (`ClearFavoritesButton`). Papelera.
  static const tvFavoritesClear = ReiconIcons.trash4;

  /// Toggle favorito idle — no está en favoritos (`FavoriteButton`).
  static const tvFavoritesHeart = ReiconIcons.heart;

  /// Toggle favorito active — canal en favoritos (`FavoriteButton`).
  static const tvFavoritesHeartSelected = ReiconFilledIcons.heart;

  /// Icono cabecera modal crear grupo de marcadores (`CreateGroupButton`).
  static const tvGroupCreateDialogTitle = ReiconIcons.bookmark;

  /// Icono campo de texto nombre en modal crear grupo de marcadores (`CreateGroupButton`).
  static const tvGroupCreateDialogInput = ReiconIcons.keyboard;

  /// Icono por defecto de un grupo de marcadores.
  static const tvBookmarkGroupLeading = ReiconIcons.shareCircle;

  /// Botón «crear grupo» (`create_group_button.dart`).
  static const groupCreate = ReiconIcons.bookmarkAdd;

  /// Ícono de grupo «Favoritos» (clave guardada `'favorite'`).
  static const groupIconFavorite = ReiconIcons.heart;

  /// Ícono de grupo «Sin adultos (+18)» (clave guardada `'no_adults'`).
  static const groupIconAdults = ReiconIcons.explicit;

  /// Ícono de grupo «Fútbol» (clave guardada `'sports_soccer'`).
  static const groupIconSoccer = ReiconIcons.football;

  /// Ícono de grupo «Películas» (clave guardada `'movie'`).
  static const groupIconMovies = ReiconIcons.clapperboardOpen;

  /// Ícono de grupo «Infantil» (clave guardada `'child_hat'`).
  static const groupIconKids = ReiconIcons.balloon;

  /// Ícono de grupo «Noticias» (clave guardada `'newspaper'`).
  static const groupIconNews = ReiconIcons.memo;

  /// Ícono de grupo «TV general» (clave guardada `'tv_gen'`).
  static const groupIconTv = ReiconIcons.tv;

  /// Ícono de grupo «Idioma» (clave guardada `'language'`).
  static const groupIconLanguage = ReiconIcons.language;

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
  // TV — categorías de canales
  // Mapa por nombre de categoría. Consumidor: `widgets/cards/category_card.dart` → [tvCategoryIconFor].
  // ---------------------------------------------------------------------------

  /// «Aire» — ondas / aire.
  static const tvCategoryAire = ReiconIcons.signalStream;

  /// «Interior» / «Provinciales» — ciudad.
  static const tvCategoryInterior = ReiconIcons.city;

  /// «Deportes» — pelota.
  static const tvCategoryDeportes = ReiconIcons.football;

  /// «Noticias» — periódico.
  static const tvCategoryNoticias = ReiconIcons.memo;

  /// «Infantiles» / «Infantil» — gorro niño.
  static const tvCategoryInfantiles = ReiconIcons.balloon;

  /// «Entretenimiento» / «Teleshows» — ticket.
  static const tvCategoryEntretenimiento = ReiconIcons.ticket;

  /// «Comedia» — máscaras teatro.
  static const tvCategoryComedia = ReiconIcons.masks;

  /// «Reality» — ojo.
  static const tvCategoryReality = ReiconIcons.eye;

  /// «Anime» — animación.
  static const tvCategoryAnime = ReiconIcons.sparkles;

  /// «Cocina» — menú / cubiertos.
  static const tvCategoryCocina = ReiconIcons.chefHat;

  /// «Radios» — radio.
  static const tvCategoryRadios = ReiconIcons.radio;

  /// «Series» — TV.
  static const tvCategorySeries = ReiconIcons.videoFrame2;

  /// «Películas» / «Cine» / «Cine y Series» — claqueta / movie.
  static const tvCategoryCine = ReiconIcons.clapperboardOpen;

  /// «Documentales» — libros.
  static const tvCategoryDocumentales = ReiconIcons.book;

  /// «Música» / «Conciertos» — nota musical.
  static const tvCategoryMusica = ReiconIcons.musicNote;

  /// «Niños» — child care.
  static const tvCategoryNinos = ReiconIcons.faceSmile;

  /// «Educación» — escuela.
  static const tvCategoryEducacion = ReiconIcons.graduationCap;

  /// «Religión» / «Religioso» — rayo.
  static const tvCategoryReligion = ReiconIcons.boltLightning;

  /// «Telenovelas» / «Novelas» — corazón.
  static const tvCategoryNovelas = ReiconIcons.heart2;

  /// «Cultura» / «Cultural» — libro.
  static const tvCategoryCultura = ReiconIcons.book3;

  /// «General» — control remoto.
  static const tvCategoryGeneral = ReiconIcons.remote;

  /// «Otros» — more.
  static const tvCategoryOtros = ReiconIcons.moreCircle;

  /// «Internacional» — globo.
  static const tvCategoryInternacional = ReiconIcons.globe;

  /// «Comunitarios» — grupos.
  static const tvCategoryComunitarios = ReiconIcons.users;

  /// «Culturales» — teatros.
  static const tvCategoryCulturales = ReiconIcons.film;

  /// «Adultos» — candado.
  static const tvCategoryAdultos = ReiconIcons.lock;

  /// Fallback si la categoría no está en el mapa.
  static const tvCategoryFallback = ReiconIcons.tv;

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
  // Agenda
  // Consumidores: `features/calendar/`, `features/home/areas/home_calendar_area.dart`,
  // `state/calendar_provider.dart`.
  // ---------------------------------------------------------------------------

  /// Panel «Eventos» de la Agenda y su acceso en Ajustes.
  static const calendarEvents = ReiconIcons.calendarDay;

  /// Panel «Suscripciones» de la Agenda.
  static const calendarSubscriptions = ReiconIcons.calendarAdd;

  /// Botón «ir a hoy» (`calendar_events_panel.dart`).
  static const calendarToday = ReiconIcons.calendarDate;

  /// Día sin eventos (`calendar_day_column.dart`).
  static const calendarEmptyDay = ReiconIcons.calendarX;

  /// Aviso de evento en vivo (`calendar_provider.dart`).
  static const calendarLive = ReiconIcons.playStream;

  /// Suscripción F1 — rueda.
  static const calendarSubF1 = ReiconIcons.wheel;

  /// Suscripción LPF AR — fútbol.
  static const calendarSubLpf = ReiconIcons.football;

  /// Suscripción Champions League — trofeo.
  static const calendarSubChampions = ReiconIcons.trophy;

  /// Suscripción Premier League — fútbol.
  static const calendarSubPremier = ReiconIcons.football;

  /// Suscripción NFL — fútbol americano (pelota oval / rugby en Reicon).
  static const calendarSubNfl = ReiconIcons.rugby;

  /// Suscripción MotoGP — bandera de carrera.
  static const calendarSubMotogp = ReiconIcons.flag;

  /// Suscripción NBA — básquet.
  static const calendarSubNba = ReiconIcons.basketball;

  /// Deporte sin ícono propio — trofeo.
  static const calendarSubFallback = ReiconIcons.cupTrophy;

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

  /// Cabecera del modal (título del evento).
  static const calendarDialogTitle = ReiconIcons.calendar;

  /// Tile «Horario».
  static const calendarDialogTime = ReiconIcons.timer2;

  /// Tile «Deporte».
  static const calendarDialogSport = ReiconIcons.football;

  /// Tile «Transmisión».
  static const calendarDialogBroadcast = ReiconIcons.tv;

  // ---------------------------------------------------------------------------
  // Arcade
  // Consumidores: `features/games/`, `features/home/areas/home_arcade_area.dart`.
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

  /// Control de juego (configuración, invitaciones, controles conectados).
  static const gamepad = ReiconIcons.gamepad;

  /// Control de juego relleno (pantalla de juego, acordeón Arcade).
  static const gamepadFilled = ReiconFilledIcons.gamepad;

  /// Control remoto del TV como mando (`arcade_screen.dart`).
  static const remote = ReiconIcons.remote;

  /// Cruceta del control en pantalla (`arcade_controller_overlay.dart`).
  static const dpadUp = ReiconIcons.chevronUp;

  /// Cruceta del control en pantalla (`arcade_controller_overlay.dart`).
  static const dpadDown = ReiconIcons.chevronDown;

  /// Cruceta del control en pantalla (`arcade_controller_overlay.dart`).
  static const dpadLeft = ReiconIcons.chevronLeft;

  /// Cruceta del control en pantalla (`arcade_controller_overlay.dart`).
  static const dpadRight = ReiconIcons.chevronRight;

  // ---------------------------------------------------------------------------
  // Amigos y Miremos juntos
  // Consumidores: `widgets/dialogs/tv_friends*`, `widgets/player/watch_party_overlay.dart`, ajustes.
  // ---------------------------------------------------------------------------

  /// Amigos / jugar con un amigo.
  static const friends = ReiconIcons.users;

  /// Resumen de amigos en Ajustes › Miremos juntos.
  static const watchPartyFriends = ReiconIcons.people2;

  /// Sin amigos todavía.
  static const friendsEmpty = ReiconIcons.userX;

  /// Solicitudes de amistad recibidas.
  static const friendRequests = ReiconIcons.deviceMessage2;

  /// Persona / amigo en listas.
  static const person = ReiconIcons.user;

  /// Perfil propio (apodo y código).
  static const profile = ReiconIcons.userSquare;

  /// Apodo / código de amigo.
  static const nickname = ReiconIcons.userId;

  /// Agregar amigo.
  static const personAdd = ReiconIcons.userAdd;

  /// Quitar amigo.
  static const personRemove = ReiconIcons.userMinus;

  /// Buscar amigo para invitar.
  static const personSearch = ReiconIcons.userSearch;

  /// Sección «Miremos juntos» en Ajustes.
  static const watchParty = ReiconIcons.msgBubbleUser;

  /// Micrófono (mensajes de voz).
  static const mic = ReiconIcons.microphone;

  /// Prueba / ajustes de micrófono.
  static const micSettings = ReiconIcons.tuning3;

  /// Mensajes de voz.
  static const voice = ReiconIcons.userSpeak;

  /// Grabando.
  static const record = ReiconIcons.record;

  /// Detener.
  static const stop = ReiconIcons.stop;

  /// Detener (circular).
  static const stopCircle = ReiconIcons.stopCircle;

  /// Volumen / reproducir audio.
  static const volume = ReiconIcons.volumeUp;

  /// Consejo / sugerencia.
  static const tip = ReiconIcons.bulb;

  // ---------------------------------------------------------------------------
  // Ajustes
  // Consumidores: `features/home/areas/home_settings_area.dart`, `features/settings/`.
  // ---------------------------------------------------------------------------

  /// Opción «Pestaña de arranque» en configuración de TV (`settings_tv_startup_tab`).
  static const settingsTvStartupTab = ReiconIcons.flag2;

  /// Sección «Generales».
  static const settingsGeneral = ReiconIcons.tuning;

  /// Sección «Películas y series».
  static const settingsMovies = ReiconIcons.clapperboardOpen;

  /// TV (sección de TV en Ajustes, amigo mirando un canal).
  static const tv = ReiconIcons.tv;

  /// Color de acento.
  static const palette = ReiconIcons.palette2;

  /// Color de acento automático (`accent_color_screen.dart`).
  static const autoAccent = ReiconIcons.sparkles;

  /// Tema claro/oscuro.
  static const darkMode = ReiconIcons.darkLight;

  /// Ajuste de clima.
  static const weather = ReiconIcons.cloudSun2;

  /// Calibración de pantalla (overscan).
  static const screenCalibration = ReiconIcons.fullscreenSquare;

  /// Sonidos de navegación apagados.
  static const volumeOff = ReiconIcons.volumeX;

  /// Extensiones (plugins).
  static const extension = ReiconIcons.puzzle;

  /// Sin extensiones instaladas.
  static const extensionEmpty = ReiconIcons.lightbulb3;

  /// Extensión instalada / fuente de canales.
  static const plugin = ReiconIcons.plugCircle;

  /// Actualizar extensión.
  static const pluginUpdate = ReiconIcons.phoneUpdate;

  /// Mostrar etiquetas de canales.
  static const channelLabels = ReiconIcons.tag2;

  /// Mostrar panel de depuración.
  static const debugPanel = ReiconIcons.searchBug;

  /// Panel de depuración en TV.
  static const debug = ReiconIcons.bug;

  /// Contenido para adultos bloqueado.
  static const lock = ReiconIcons.lockPassword;

  /// Contenido para adultos desbloqueado.
  static const lockOpen = ReiconIcons.lockPasswordOpen;

  /// PIN parental.
  static const pin = ReiconIcons.password;

  /// Avisos de la Agenda.
  static const notifications = ReiconIcons.bell;

  /// Duración de los avisos.
  static const timer = ReiconIcons.timer2;

  /// Zona horaria.
  static const timeZone = ReiconIcons.globe2;

  /// Actualizar catálogo de películas.
  static const catalogSync = ReiconIcons.globalRefresh2;

  /// Sin catálogo descargado.
  static const catalogEmpty = ReiconIcons.cloudCross2;

  /// Actualización de la app.
  static const appUpdate = ReiconIcons.desktopDownload;

  /// Instalación pendiente.
  static const installPending = ReiconIcons.squareArrowDown;

  /// Acerca de: canales disponibles.
  static const channelGuide = ReiconIcons.videoLib;

  /// Salir de la app.
  static const exitApp = ReiconIcons.logout;

  /// Dispositivo bloqueado (`blocked_screen.dart`).
  static const blocked = ReiconIcons.ban;

  // ---------------------------------------------------------------------------
  // Clima y ubicación
  // Consumidores: `widgets/dialogs/tv_weather_location_dialog.dart`, clima del rail.
  // ---------------------------------------------------------------------------

  /// Clima sin animación disponible.
  static const weatherFallback = ReiconIcons.sun;

  /// Resultado de búsqueda de ubicación.
  static const weatherLocationItem = ReiconIcons.mapPoint;

  /// Buscar ubicación.
  static const locationSearch = ReiconIcons.pinSearch;

  /// Usar mi ubicación.
  static const myLocation = ReiconIcons.location2;

  /// Sin resultados de ubicación / zona.
  static const locationEmpty = ReiconIcons.locationSlash2;

  // ---------------------------------------------------------------------------
  // Calibración de pantalla
  // Consumidor: `features/bootstrap/screens/overlap_config_screen.dart`.
  // ---------------------------------------------------------------------------

  /// Esquina superior derecha.
  static const northEast = ReiconIcons.arrowRightUp;

  /// Esquina superior izquierda.
  static const northWest = ReiconIcons.arrowLeftUp;

  /// Esquina inferior derecha.
  static const southEast = ReiconIcons.arrowRightDown;

  /// Esquina inferior izquierda.
  static const southWest = ReiconIcons.arrowLeftDown;

  // ---------------------------------------------------------------------------
  // Acciones y estados comunes
  // ---------------------------------------------------------------------------

  /// Confirmado / seleccionado.
  static const check = ReiconIcons.check;

  /// Éxito.
  static const checkCircle = ReiconIcons.checkCircle;

  /// Éxito (relleno).
  static const checkCircleFilled = ReiconFilledIcons.checkCircle;

  /// Error.
  static const error = ReiconIcons.alertCircle;

  /// Error (relleno).
  static const errorFilled = ReiconFilledIcons.alertCircle;

  /// Advertencia.
  static const warning = ReiconIcons.alertTriangle;

  /// Advertencia (relleno).
  static const warningFilled = ReiconFilledIcons.alertTriangle;

  /// Información.
  static const info = ReiconIcons.circleInfo;

  /// Información (variante circular).
  static const infoCircle = ReiconIcons.infoCircle;

  /// Sin conexión.
  static const offline = ReiconIcons.wifiOff;

  /// Borrar.
  static const delete = ReiconIcons.trash4;

  /// Reintentar / recargar.
  static const refresh = ReiconIcons.refresh;

  /// Sincronizar extensión.
  static const sync = ReiconIcons.refresh2;

  /// Cerrar.
  static const close = ReiconIcons.x;

  /// Limpiar texto.
  static const clear = ReiconIcons.xCircle;

  /// Buscar.
  static const search = ReiconIcons.search;

  /// Escribir con el teclado en pantalla.
  static const keyboard = ReiconIcons.keyboard;

  // ---------------------------------------------------------------------------
  // Flechas
  // ---------------------------------------------------------------------------

  /// Volver.
  static const arrowBack = ReiconIcons.arrowLeft;

  /// Avanzar.
  static const arrowForward = ReiconIcons.arrowRight;

  /// Arriba.
  static const arrowUp = ReiconIcons.arrowUp;

  /// Abajo.
  static const arrowDown = ReiconIcons.arrowDown;

  /// Volver en la cabecera de un panel (`tv_panel_header.dart`).
  static const panelBack = ReiconIcons.arrowLeft2;

  /// Semana anterior / ir a la izquierda.
  static const chevronLeft = ReiconIcons.chevronLeft;

  /// Semana siguiente / abrir detalle.
  static const chevronRight = ReiconIcons.arrowRight2;

  /// Hay más contenido arriba en listas y grillas.
  static const chevronUp = ReiconIcons.chevronUp;

  /// Hay más contenido abajo en listas y grillas.
  static const chevronDown = ReiconIcons.chevronDown;

  // ---------------------------------------------------------------------------
  // Películas y series (VOD)
  // Consumidores: `features/movies/`, `features/home/areas/home_movies_area.dart`.
  // ---------------------------------------------------------------------------

  /// Estado vacío del catálogo de películas (`movies_empty_featured`).
  static const tvMoviesEmpty = ReiconIcons.cloudDownload;

  /// Panel Buscar de Películas (columna del acordeón y campo vacío).
  static const moviesSearch = ReiconIcons.search4;

  /// Una búsqueda reciente en Buscar de Películas.
  static const moviesSearchRecent = ReiconIcons.history;

  /// Resultados del catálogo guardado: el servidor no contestó.
  static const moviesSearchOffline = ReiconIcons.wifiOff;

  /// Tarjeta: película.
  static const vodMovie = ReiconIcons.videoFrame2;

  /// Tarjeta: serie.
  static const vodSeries = ReiconIcons.clapperboardText;

  /// Tarjeta: tráiler.
  static const vodTrailer = ReiconIcons.reel;

  /// Pestaña del detalle de la película.
  static const vodPoster = ReiconIcons.clapperboardOpen;

  /// "Interesantes": el mismo en la tarjeta del Inicio, sus opciones y el
  /// botón del detalle (marcada o no).
  static const vodWatchlist = ReiconIcons.ticket;

  /// Descuentos en comercios (tarjeta del Inicio).
  static const discounts = ReiconIcons.percentTag;

  /// Bancos y billeteras del usuario, para los descuentos.
  static const discountBanks = ReiconIcons.wallet3;

  /// "Mis comercios" (dónde compra el usuario).
  static const discountMerchants = ReiconIcons.shop;

  /// Localidad del usuario (la del clima), en Descuentos.
  static const discountLocation = ReiconIcons.location2;

  /// Filtro "Mis comercios / Todos" y de rubro en la semana de descuentos.
  static const discountFilter = ReiconIcons.filter;

  /// Rubros de descuentos.
  static const discountRubroSuper = ReiconIcons.cartShopping;
  static const discountRubroMayoristas = ReiconIcons.truck;
  static const discountRubroFarmacias = ReiconIcons.pills;
  static const discountRubroCombustible = ReiconIcons.gasStation;

  /// Puntaje de la película.
  static const vodRatingFilled = ReiconFilledIcons.star;

  /// Fecha de estreno.
  static const vodReleaseDate = ReiconIcons.calendar;

  /// Duración.
  static const vodDuration = ReiconIcons.clockCircle;

  /// Calidad de video.
  static const vodQuality = ReiconIcons.hd;

  /// Vista completa.
  static const vodWatched = ReiconFilledIcons.checkCircle;

  /// Continuar viendo.
  static const vodResume = ReiconIcons.history;

  /// Buscar hacia adelante (el salto puede ser de cualquier tamaño).
  static const vodSkipForward = ReiconIcons.fastForward;

  /// Buscar hacia atrás.
  static const vodSkipBack = ReiconIcons.rewind;

  /// Pista de audio.
  static const vodAudio = ReiconIcons.volumeUp;

  /// Subtítulos.
  static const vodSubtitles = ReiconIcons.text;

  /// Reproducir.
  static const vodPlay = ReiconFilledIcons.play;

  /// Pausa.
  static const vodPause = ReiconFilledIcons.pause;

  // ---------------------------------------------------------------------------
  // Teclado en pantalla y PIN
  // Consumidores: `widgets/tv_input/`, `widgets/dialogs/tv_pin/`.
  // ---------------------------------------------------------------------------

  /// Tecla mayúsculas.
  static const keyboardShift = ReiconIcons.arrowUp;

  /// Tecla borrar.
  static const keyboardBackspace = ReiconIcons.tagCross2;

  /// Borrar dígito del PIN.
  static const pinBackspace = ReiconIcons.tagCross2;

  /// Cerrar el teclado de PIN.
  static const pinClose = ReiconIcons.x;
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
