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
///
/// Tamaños: usar siempre [MoaiIconSizes], nunca un número suelto.
abstract final class MoaiIcons {
  MoaiIcons._();

  // ---------------------------------------------------------------------------
  // 1. Navegación — rail lateral
  // Consumidor: `features/home/widgets/tv_vertical_nav_rail.dart`.
  // ---------------------------------------------------------------------------

  /// Rail «Inicio» (sin seleccionar).
  static const railHome = HugeIcons.home09;

  /// Rail «Inicio» (seleccionado).
  static const railHomeSelected = HugeIcons.home09;

  /// Rail «TV» (sin seleccionar).
  static const railTv = HugeIcons.modernTv;

  /// Rail «TV» (seleccionado).
  static const railTvSelected = HugeIcons.modernTv;

  /// Rail «Destacados» (sin seleccionar).
  static const railFeatured = HugeIcons.video01;

  /// Rail «Destacados» (seleccionado).
  static const railFeaturedSelected = HugeIcons.video01;

  /// Rail «Películas» (sin seleccionar).
  static const railMovies = HugeIcons.clapperboard;

  /// Rail «Películas» (seleccionado).
  static const railMoviesSelected = HugeIcons.clapperboard;

  /// Rail «Series» (sin seleccionar).
  static const railSeries = HugeIcons.film01;

  /// Rail «Series» (seleccionado).
  static const railSeriesSelected = HugeIcons.film01;

  /// Rail «Agenda» (sin seleccionar).
  static const railCalendar = HugeIcons.calendar03;

  /// Rail «Agenda» (seleccionado).
  static const railCalendarSelected = HugeIcons.calendar03;

  /// Rail «Descuentos» (sin seleccionar / seleccionado).
  static const railDiscounts = HugeIcons.discountTag02;
  static const railDiscountsSelected = HugeIcons.discountTag02;

  /// Rail «Arcade» (sin seleccionar).
  static const railArcade = HugeIcons.gameController03;

  /// Rail «Arcade» (seleccionado).
  static const railArcadeSelected = HugeIcons.gameController03;

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
  static const tvAccordionHome = HugeIcons.home09;

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
  static const tvChannelLogoFallback = HugeIcons.tv02;

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

  /// Suscripción MotoGP — motocicleta.
  static const calendarSubMotogp = HugeIcons.motorbike02;

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

  /// 1. Seleccionar juego Arcade (fantasma)
  static const arcadeActionSelectGame = HugeIcons.ghost;

  /// 2. Configurar Gamepad Arcade (gamepad)
  static const arcadeActionConfigGamepad = HugeIcons.gameController03;

  /// 3. Iniciar juego Arcade (play)
  static const arcadeActionStartGame = HugeIcons.play;

  /// Refrescar catálogo de ROMs (refresh)
  static const arcadeCatalogRefresh = HugeIcons.refresh;

  /// Ícono de ROM / Juego en catálogo
  static const arcadeRomItem = HugeIcons.ghost;

  /// Ícono del badge/pill de instalados en cabecera de Arcade (gameboy)
  static const arcadeRomInstalledBadge = HugeIcons.gameboy;

  /// Ícono de la tarjeta de juego instalado (gamepad)
  static const arcadeRomCard = HugeIcons.gameController03;

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

  /// Resumen de amigos en Ajustes › Miremos juntos.
  static const watchPartyFriends = HugeIcons.userGroup02;

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

  /// Quitar amigo.
  static const personRemove = HugeIcons.userRemove01;

  /// Buscar amigo para invitar.
  static const personSearch = HugeIcons.userSearch01;

  /// Sección «Miremos juntos» en Ajustes.
  static const watchParty = HugeIcons.bubbleChat;

  /// Micrófono (mensajes de voz).
  static const mic = HugeIcons.mic01;

  /// Prueba / ajustes de micrófono.
  static const micSettings = HugeIcons.slidersHorizontal;

  /// Mensajes de voz.
  static const voice = HugeIcons.mic01;

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
  static const plugin = HugeIcons.plug01;

  /// Actualizar extensión.
  static const pluginUpdate = HugeIcons.refresh01;

  /// Avisos de la Agenda.
  static const notifications = HugeIcons.bell;

  /// Duración de los avisos.
  static const timer = HugeIcons.timer01;

  /// Zona horaria.
  static const timeZone = HugeIcons.globe;

  /// Actualizar catálogo de películas.
  static const catalogSync = HugeIcons.refresh;

  /// Sin catálogo descargado.
  static const catalogEmpty = HugeIcons.cloudAlert;

  /// Actualización de la app.
  static const appUpdate = HugeIcons.download01;

  /// Instalación pendiente.
  static const installPending = HugeIcons.download01;

  /// Acerca de: canales disponibles.
  static const channelGuide = HugeIcons.tv01;

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

  // ---------------------------------------------------------------------------
  // 12. Acciones y estados comunes
  // ---------------------------------------------------------------------------

  /// Confirmado / seleccionado.
  static const check = HugeIcons.tick01;

  /// Éxito.
  static const checkCircle = HugeIcons.checkmarkCircle01;

  /// Éxito (relleno/seleccionado).
  static const checkCircleFilled = HugeIcons.checkmarkCircle01;

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
  static const moviesShowAll = HugeIcons.dashboardSquare01;

  /// Tarjeta: película.
  static const vodMovie = HugeIcons.clapperboard;

  /// Tarjeta: serie.
  static const vodSeries = HugeIcons.film01;

  /// Tarjeta: tráiler.
  static const vodTrailer = HugeIcons.video01;

  /// Pestaña del detalle de la película.
  static const vodPoster = HugeIcons.clapperboard;

  /// "Interesantes": el mismo en la tarjeta del Inicio, sus opciones y el
  /// botón del detalle (marcada o no).
  static const vodWatchlist = HugeIcons.ticket01;

  /// Descuentos en comercios (tarjeta del Inicio).
  static const discounts = HugeIcons.discountTag02;

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
  static const vodWatched = HugeIcons.checkmarkCircle01;

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

  /// Reproducir.
  static const vodPlay = HugeIcons.play;

  /// Pausa.
  static const vodPause = HugeIcons.pause;

  // ---------------------------------------------------------------------------
  // 15. Teclado en pantalla y PIN
  // Consumidores: `widgets/tv_input/`, `widgets/dialogs/tv_pin/`.
  // ---------------------------------------------------------------------------

  /// Tecla mayúsculas.
  static const keyboardShift = HugeIcons.arrowUp01;

  /// Tecla borrar.
  static const keyboardBackspace = HugeIcons.delete02;

  /// Borrar dígito del PIN.
  static const pinBackspace = HugeIcons.delete02;

  /// Cerrar el teclado de PIN.
  static const pinClose = HugeIcons.cancel01;
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
