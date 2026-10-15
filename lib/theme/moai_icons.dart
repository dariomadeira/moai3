import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:reicons/reicons.dart';

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

  /// Rail TV (idle). Origen: `ReiconIcons.tv`
  static const railTv = ReiconIcons.tv;

  /// Rail TV (selected). Origen: `ReiconFilledIcons.tv`
  static const railTvSelected = ReiconFilledIcons.tv;

  /// Rail Películas (idle). Origen: `ReiconIcons.clapperboard`
  static const railMovies = ReiconIcons.videoFrame2;

  /// Rail Películas (selected). Origen: `ReiconFilledIcons.clapperboard`
  static const railMoviesSelected = ReiconFilledIcons.videoFrame2;

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
  // Usado en `features/home/widgets/channel_viewer_header.dart`.
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

  /// Toggle favorito idle — no está en favoritos (`FavoriteButton`).
  /// Origen actual: `Icons.favorite_outline`
  static const tvFavoritesHeart = ReiconIcons.heart;

  /// Toggle favorito active — canal en favoritos (`FavoriteButton`).
  /// Origen actual: `Icons.favorite`
  static const tvFavoritesHeartSelected = ReiconFilledIcons.heart;

  // ---------------------------------------------------------------------------
  // Tarjeta de canal — placeholder sin logo
  // Consumidor: `widgets/cards/tv_list_card_leading_logo.dart`
  // ---------------------------------------------------------------------------

  /// Sin logo / logo fallido en la grilla o lista de canales.
  /// Origen: `ReiconIcons.display`
  static const tvChannelLogoFallback = ReiconIcons.display;

  // ---------------------------------------------------------------------------
  // Categorías de canales (lista Categorías / CategoryCard)
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

  /// Resuelve el icono de una categoría por nombre (o [tvCategoryFallback]).
  static IconData tvCategoryIconFor(String category) =>
      tvCategoryIcons[category] ?? tvCategoryFallback;

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
  // Material / Symbols (resto de la UI)
  // ---------------------------------------------------------------------------

  /// Origen: `Icons.tv`
  static const tv = Icons.tv;

  /// Origen: `Icons.tv_outlined`
  ///
  /// Usos:
  /// - Agenda: `calendar_event_broadcaster` (`features/calendar/widgets/calendar_events_panel.dart`)
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  /// - Placeholder sin logo: ver [tvChannelLogoFallback]
  static const tvOutlined = Icons.tv_outlined;

  /// Origen: `Icons.calendar_month`
  static const calendarMonth = Icons.calendar_month;

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

  /// Origen: `Icons.settings_outlined`
  static const settingsOutlined = Icons.settings_outlined;

  /// Origen: `Symbols.adaptive_audio_mic`
  ///
  /// Usos:
  /// - Inicio / menú lateral (`features/home/areas/home_settings_area.dart`)
  static const adaptiveAudioMic = Symbols.adaptive_audio_mic;

  /// Origen: `Icons.add_rounded`
  ///
  /// Usos:
  /// - Favoritos barra: ver alias [tvFavoritesAdd]
  static const addRounded = Icons.add_rounded;

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

  /// Origen: `Icons.arrow_back_outlined`
  ///
  /// Usos:
  /// - Componentes TV compartidos (`widgets/tv_common/tv_panel_header.dart`)
  static const arrowBackOutlined = Icons.arrow_back_outlined;

  /// Origen: `Icons.arrow_back_rounded`
  ///
  /// Usos:
  /// - Ajustes (`features/settings/screens/friends_screen.dart`)
  /// - Arcade (`features/games/screens/arcade_games_screen.dart`)
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  /// - Extensiones (`features/plugins/screens/general_plugins_screen.dart`)
  /// - Extensiones (`features/sources/screens/sources_screen.dart`)
  static const arrowBackRounded = Icons.arrow_back_rounded;

  /// Origen: `Icons.arrow_downward_rounded`
  ///
  /// Usos:
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const arrowDownwardRounded = Icons.arrow_downward_rounded;

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

  /// Origen: `Icons.arrow_forward_rounded`
  ///
  /// Usos:
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const arrowForwardRounded = Icons.arrow_forward_rounded;

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

  /// Origen: `Icons.arrow_upward_rounded`
  ///
  /// Usos:
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const arrowUpwardRounded = Icons.arrow_upward_rounded;

  /// Origen: `Icons.aspect_ratio_outlined`
  ///
  /// Usos:
  /// - Ajustes: `settings_general_overscan_desc` (`features/settings/widgets/settings_general_panel.dart`)
  /// - Configuración inicial (`features/bootstrap/screens/overlap_config_screen.dart`)
  static const aspectRatioOutlined = Icons.aspect_ratio_outlined;

  /// Origen: `Icons.auto_awesome_outlined`
  ///
  /// Usos:
  /// - Ajustes: `settings_general_auto_accent_desc` (`features/settings/widgets/settings_general_panel.dart`)
  static const autoAwesomeOutlined = Icons.auto_awesome_outlined;

  /// Origen: `Icons.backspace_outlined`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_pin_dialog.dart`)
  static const backspaceOutlined = Icons.backspace_outlined;

  /// Origen: `Icons.badge_outlined`
  ///
  /// Usos:
  /// - Ajustes: `friends_input_label` (`features/settings/screens/friends_screen.dart`)
  /// - Ajustes: `settings_tv_watch_party_code_desc` (`features/settings/widgets/settings_watch_party_panel.dart`)
  /// - Amigos / Ver juntos: `friends_input_label` (`widgets/dialogs/tv_friends_dialog.dart`)
  /// - Amigos / Ver juntos: `nickname_dialog_subtitle_setup` (`widgets/dialogs/tv_nickname_dialog.dart`)
  static const badgeOutlined = Icons.badge_outlined;

  /// Origen: `Icons.block`
  ///
  /// Usos:
  /// - Dispositivo bloqueado (`features/blocked/screens/blocked_screen.dart`)
  static const block = Icons.block;

  /// Origen: `Symbols.book_2`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const book2 = Symbols.book_2;

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

  /// Origen: `Icons.bookmarks_outlined`
  ///
  /// Usos:
  /// - TV / canales: `browser_groups_empty` (`features/groups/widgets/group_list_panel.dart`)
  /// - Pestañas TV: ver alias [tvTabMarcadores]
  static const bookmarksOutlined = Icons.bookmarks_outlined;

  /// Origen: `Symbols.bookmark_heart`
  ///
  /// Usos:
  /// - Marcadores / grupos (`widgets/cards/group_card.dart`)
  static const bookmarkHeart = Symbols.bookmark_heart;

  /// Origen: `Symbols.browser_updated`
  ///
  /// Usos:
  /// - Actualizaciones: `update_mandatory_title` (`widgets/dialogs/update_dialog.dart`)
  /// - Ajustes: `settings_about_check_updates_desc` (`features/settings/widgets/settings_about_panel.dart`)
  static const browserUpdated = Symbols.browser_updated;

  /// Origen: `Icons.bug_report_outlined`
  ///
  /// Usos:
  /// - TV / canales (`features/home/areas/home_tv_area.dart`)
  static const bugReportOutlined = Icons.bug_report_outlined;

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

  /// Origen: `Icons.category_outlined`
  ///
  /// Usos:
  /// - TV / canales: `browser_categories_empty` (`features/channel_browser/widgets/category_list_panel.dart`)
  /// - Acordeón Explorar: ver alias [tvAccordionCategorias]
  /// - Visor canal: ver alias [tvViewerPillCategory]
  static const categoryOutlined = Icons.category_outlined;

  /// Origen: `Icons.check`
  ///
  /// Usos:
  /// - Ajustes (`features/settings/screens/agenda_utc_offset_screen.dart`)
  /// - Ajustes: `friends_delete_success` (`features/settings/screens/friends_screen.dart`)
  static const check = Icons.check;

  /// Origen: `Symbols.check_circle`
  ///
  /// Usos:
  /// - Actualizaciones (`widgets/dialogs/plugin_update_dialog.dart`)
  static const checkCircle = Symbols.check_circle;

  /// Origen: `Icons.check_circle_outline`
  ///
  /// Usos:
  /// - Ajustes: `friend_add_dialog_success` (`features/settings/screens/friends_screen.dart`)
  /// - Ajustes: `nickname_dialog_saved_success` (`features/settings/widgets/settings_watch_party_panel.dart`)
  /// - Amigos / Ver juntos: `friend_add_dialog_success` (`widgets/dialogs/tv_add_friend_dialog.dart`)
  /// - Amigos / Ver juntos: `parental_pin_created_success` (`widgets/dialogs/tv_pin_dialog.dart`)
  /// - Avisos (`helpers/notification_helper.dart`)
  /// - Avisos (`widgets/feedback/moai_snackbar.dart`)
  static const checkCircleOutline = Icons.check_circle_outline;

  /// Origen: `Icons.check_circle_outline_rounded`
  ///
  /// Usos:
  /// - Arcade (`features/games/screens/arcade_games_screen.dart`)
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  /// - Extensiones (`features/plugins/screens/general_plugins_screen.dart`)
  /// - Extensiones (`features/sources/screens/sources_screen.dart`)
  static const checkCircleOutlineRounded = Icons.check_circle_outline_rounded;

  /// Origen: `Icons.check_circle_rounded`
  ///
  /// Usos:
  /// - Arcade (`features/games/widgets/tv_arcade_prep_dialog.dart`)
  /// - Clima: `weather_location_configured` (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const checkCircleRounded = Icons.check_circle_rounded;

  /// Origen: `Icons.check_outlined`
  ///
  /// Usos:
  /// - Configuración inicial: `overlap_save` (`features/bootstrap/screens/overlap_config_screen.dart`)
  static const checkOutlined = Icons.check_outlined;

  /// Origen: `Icons.check_rounded`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  /// - Arcade / gamepad: `gamepad_action_close` (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  /// - Clima (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const checkRounded = Icons.check_rounded;

  /// Origen: `Icons.chevron_left`
  ///
  /// Usos:
  /// - Agenda: `calendar_week_nav_prev` (`features/calendar/widgets/calendar_events_panel.dart`)
  static const chevronLeft = Icons.chevron_left;

  /// Origen: `Icons.chevron_right`
  ///
  /// Usos:
  /// - Agenda: `calendar_week_nav_next` (`features/calendar/widgets/calendar_events_panel.dart`)
  /// - Ajustes (`features/settings/widgets/settings_widgets.dart`)
  static const chevronRight = Icons.chevron_right;

  /// Origen: `Symbols.child_care`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const childCare = Symbols.child_care;

  /// Origen: `Icons.child_care_outlined`
  ///
  /// Usos:
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  static const childCareOutlined = Icons.child_care_outlined;

  /// Origen: `Symbols.child_hat`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const childHat = Symbols.child_hat;

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

  /// Origen: `Icons.cloud_outlined`
  ///
  /// Usos:
  /// - Ajustes: `settings_general_weather_title` (`features/settings/widgets/settings_general_panel.dart`)
  static const cloudOutlined = Icons.cloud_outlined;

  /// Origen: `Icons.cloud_sync_outlined`
  ///
  /// Usos:
  /// - Ajustes películas: actualizar catálogo al arrancar
  static const cloudSyncOutlined = Icons.cloud_sync_outlined;

  /// Origen: `Symbols.confirmation_number`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const confirmationNumber = Symbols.confirmation_number;

  /// Origen: `Icons.dark_mode_outlined`
  ///
  /// Usos:
  /// - Ajustes: `settings_general_dark_mode_desc` (`features/settings/widgets/settings_general_panel.dart`)
  static const darkModeOutlined = Icons.dark_mode_outlined;

  /// Origen: `Symbols.delete`
  ///
  /// Usos:
  /// - Inicio (`features/home/widgets/alphabet_jump_panel.dart`)
  static const delete = Symbols.delete;

  /// Origen: `Icons.delete_outline_rounded`
  ///
  /// Usos:
  /// - Ajustes: `friends_delete_button` (`features/settings/screens/friends_screen.dart`)
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

  /// Origen: `Icons.dns_outlined`
  ///
  /// Usos:
  /// - TV / canales: `player_server_n` (`features/home/widgets/channel_viewer_header.dart`)
  static const dnsOutlined = Icons.dns_outlined;

  /// Origen: `Symbols.download`
  ///
  /// Usos:
  /// - Arcade (`features/games/screens/arcade_games_screen.dart`)
  /// - Extensiones (`features/plugins/screens/general_plugins_screen.dart`)
  /// - Extensiones (`features/sources/screens/sources_screen.dart`)
  static const download = Symbols.download;

  /// Origen: `Symbols.electrical_services`
  ///
  /// Usos:
  /// - Actualizaciones (`widgets/dialogs/plugin_update_dialog.dart`)
  /// - Extensiones (`features/plugins/screens/general_plugins_screen.dart`)
  /// - Extensiones (`features/sources/screens/sources_screen.dart`)
  static const electricalServices = Symbols.electrical_services;

  /// Origen: `Icons.emoji_events_outlined`
  ///
  /// Usos:
  /// - Alias agrupado: [calendarSubChampions]
  static const emojiEventsOutlined = Icons.emoji_events_outlined;

  /// Origen: `Symbols.error`
  ///
  /// Usos:
  /// - Actualizaciones (`widgets/dialogs/plugin_update_dialog.dart`)
  /// - Actualizaciones (`widgets/dialogs/update_dialog.dart`)
  static const error = Symbols.error;

  /// Origen: `Icons.error_outline`
  ///
  /// Usos:
  /// - Ajustes: `friends_delete_error` (`features/settings/screens/friends_screen.dart`)
  /// - Ajustes: `nickname_dialog_saved_error` (`features/settings/widgets/settings_watch_party_panel.dart`)
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_add_friend_dialog.dart`)
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_pin_dialog.dart`)
  /// - Avisos (`helpers/notification_helper.dart`)
  /// - Avisos (`widgets/feedback/moai_snackbar.dart`)
  /// - Botones compartidos: `groups_create_error` (`widgets/buttons/create_group_button.dart`)
  /// - Reproductor (`widgets/player/viewer_error_display.dart`)
  static const errorOutline = Icons.error_outline;

  /// Origen: `Icons.error_outline_rounded`
  ///
  /// Usos:
  /// - Ajustes (`features/settings/screens/friends_screen.dart`)
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  /// - Extensiones (`features/sources/screens/sources_screen.dart`)
  static const errorOutlineRounded = Icons.error_outline_rounded;

  /// Origen: `Icons.event_busy_outlined`
  ///
  /// Usos:
  /// - Agenda (`features/calendar/widgets/calendar_events_panel.dart`)
  static const eventBusyOutlined = Icons.event_busy_outlined;

  /// Origen: `Icons.event_note_outlined`
  ///
  /// Usos:
  /// - Agenda (`features/calendar/widgets/calendar_events_panel.dart`)
  static const eventNoteOutlined = Icons.event_note_outlined;

  /// Origen: `Icons.exit_to_app_outlined`
  ///
  /// Usos:
  /// - Inicio: `home_exit_double_back` (`features/home/widgets/double_back_exit_scope.dart`)
  static const exitToAppOutlined = Icons.exit_to_app_outlined;

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

  /// Origen: `Icons.explore_outlined`
  ///
  /// Usos:
  /// - TV / canales (`features/search/widgets/search_panel.dart`)
  /// - Pestañas TV: ver alias [tvTabExplorar]
  static const exploreOutlined = Icons.explore_outlined;

  /// Origen: `Symbols.extension`
  ///
  /// Usos:
  /// - Actualizaciones: `plugin_update_title_singular` (`widgets/dialogs/plugin_update_dialog.dart`)
  /// - Ajustes: `settings_general_sources_desc` (`features/settings/widgets/settings_tv_panel.dart`)
  /// - Extensiones (`features/plugins/screens/general_plugins_screen.dart`)
  /// - Extensiones (`features/sources/screens/sources_screen.dart`)
  static const extension = Symbols.extension;

  /// Origen: `Icons.extension_off_outlined`
  ///
  /// Usos:
  /// - Extensiones: `plugins_empty_installed_msg` (`features/plugins/screens/general_plugins_screen.dart`)
  /// - Extensiones: `sources_empty` (`features/sources/screens/sources_screen.dart`)
  static const extensionOffOutlined = Icons.extension_off_outlined;

  /// Origen: `Icons.extension_outlined`
  ///
  /// Usos:
  /// - Ajustes: `settings_general_plugins_title` (`features/settings/widgets/settings_general_panel.dart`)
  /// - Visor canal: ver alias [tvViewerPillPlugin]
  static const extensionOutlined = Icons.extension_outlined;

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

  /// Origen: `Icons.fiber_manual_record`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `mic_test_btn_record` (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const fiberManualRecord = Icons.fiber_manual_record;

  /// Origen: `Symbols.gamepad`
  ///
  /// Usos:
  /// - Arcade: `arcade_gamepad_config_title` (`features/home/areas/home_arcade_area.dart`)
  /// - Arcade / gamepad: `gamepad_detected_section_header` (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const gamepad = Symbols.gamepad;

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

  /// Origen: `Icons.group_off_outlined`
  ///
  /// Usos:
  /// - Ajustes: `friends_empty_title` (`features/settings/screens/friends_screen.dart`)
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  /// - Arcade (`features/games/widgets/tv_arcade_select_friend_dialog.dart`)
  static const groupOffOutlined = Icons.group_off_outlined;

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

  /// Origen: `Symbols.host`
  ///
  /// Usos:
  /// - Botones compartidos (`widgets/buttons/server_skip_button.dart`)
  static const host = Symbols.host;

  /// Origen: `Symbols.hourglass_empty`
  ///
  /// Usos:
  /// - TV / canales: `browser_channels_empty` (`features/channel_browser/widgets/channel_list_panel.dart`)
  static const hourglassEmpty = Symbols.hourglass_empty;

  /// Origen: `Symbols.info`
  ///
  /// Usos:
  /// - Arcade / gamepad: `gamepad_support_two_players` (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const info = Symbols.info;

  /// Origen: `Icons.info_outline`
  ///
  /// Usos:
  /// - Arcade: `arcade_no_game_installed_snack` (`features/home/areas/home_arcade_area.dart`)
  /// - Avisos (`helpers/notification_helper.dart`)
  /// - Avisos (`widgets/feedback/moai_snackbar.dart`)
  /// - Inicio: `arcade_no_game_installed_snack` (`features/home/screens/home_screen.dart`)
  /// - Inicio / menú lateral (`features/home/areas/home_settings_area.dart`)
  static const infoOutline = Icons.info_outline;

  /// Origen: `Icons.info_outline_rounded`
  ///
  /// Usos:
  /// - Arcade (`features/games/widgets/tv_arcade_prep_dialog.dart`)
  /// - Clima (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const infoOutlineRounded = Icons.info_outline_rounded;

  /// Origen: `Symbols.install_desktop`
  ///
  /// Usos:
  /// - Extensiones: `sources_install` (`features/sources/screens/sources_screen.dart`)
  static const installDesktop = Symbols.install_desktop;

  /// Origen: `Symbols.joystick`
  ///
  /// Usos:
  /// - Arcade (`features/games/screens/arcade_games_screen.dart`)
  /// - Arcade: `arcade_action_select_game` (`features/home/areas/home_arcade_area.dart`)
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const joystick = Symbols.joystick;

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

  /// Origen: `Icons.keyboard_outlined`
  ///
  /// Usos:
  /// - Clima (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const keyboardOutlined = Icons.keyboard_outlined;

  /// Origen: `Icons.label_outline`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_channel_labels_desc` (`features/settings/widgets/settings_tv_panel.dart`)
  static const labelOutline = Icons.label_outline;

  /// Origen: `Icons.language_outlined`
  ///
  /// Usos:
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  static const languageOutlined = Icons.language_outlined;

  /// Origen: `Symbols.library_books`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const libraryBooks = Symbols.library_books;

  /// Origen: `Icons.lightbulb_outline`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const lightbulbOutline = Icons.lightbulb_outline;

  /// Origen: `Icons.link_rounded`
  ///
  /// Usos:
  /// - Arcade: `arcade_input_url_label` (`features/games/screens/arcade_games_screen.dart`)
  /// - Extensiones: `sources_url_label` (`features/sources/screens/sources_screen.dart`)
  static const linkRounded = Icons.link_rounded;

  /// Origen: `Icons.live_tv_outlined`
  ///
  /// Usos:
  /// - Agenda (`state/calendar_provider.dart`)
  /// - TV / canales (`features/home/widgets/empty_viewer_panel.dart`)
  /// - Acordeón Explorar: ver alias [tvAccordionCanales]
  static const liveTvOutlined = Icons.live_tv_outlined;

  /// Origen: `Symbols.location_city`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const locationCity = Symbols.location_city;

  /// Origen: `Icons.location_off_outlined`
  ///
  /// Usos:
  /// - Clima (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const locationOffOutlined = Icons.location_off_outlined;

  /// Origen: `Icons.location_on_outlined`
  ///
  /// Usos:
  /// - Clima: `weather_location_dialog_title` (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const locationOnOutlined = Icons.location_on_outlined;

  /// Origen: `Symbols.lock`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_adult_content_desc` (`features/settings/widgets/settings_tv_panel.dart`)
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_pin_dialog.dart`)
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const lock = Symbols.lock;

  /// Origen: `Symbols.lock_open`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_adult_content_desc` (`features/settings/widgets/settings_tv_panel.dart`)
  /// - Amigos / Ver juntos: `parental_adult_unlocked` (`widgets/dialogs/tv_pin_dialog.dart`)
  static const lockOpen = Symbols.lock_open;

  /// Origen: `Icons.mark_email_read_outlined`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  static const markEmailReadOutlined = Icons.mark_email_read_outlined;

  /// Origen: `Symbols.mic`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/player/watch_party_overlay.dart`)
  /// - Inicio (`features/home/widgets/tv_watch_party_header_bar.dart`)
  static const mic = Symbols.mic;

  /// Origen: `Symbols.mic_gear`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_mic_test_desc` (`features/settings/widgets/settings_watch_party_panel.dart`)
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const micGear = Symbols.mic_gear;

  /// Origen: `Icons.mic_none_outlined`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const micNoneOutlined = Icons.mic_none_outlined;

  /// Origen: `Symbols.more`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const more = Symbols.more;

  /// Origen: `Symbols.movie`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  /// - Inicio / menú lateral: `home_rail_movies_title` (`features/home/widgets/navigation_rail_section.dart`)
  /// - Tarjeta de película (`features/home/widgets/tv_movie_card.dart`)
  static const movie = Symbols.movie;

  /// Origen: `Icons.movie_outlined`
  ///
  /// Usos:
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  /// - Inicio / menú lateral: `home_rail_movies_title` (`features/home/widgets/navigation_rail_section.dart`)
  /// - Área películas (`features/home/areas/home_movies_area.dart`)
  static const movieOutlined = Icons.movie_outlined;

  /// Origen: `Symbols.music_note`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const musicNote = Symbols.music_note;

  /// Origen: `Icons.my_location_rounded`
  ///
  /// Usos:
  /// - Clima: `weather_location_reset_auto` (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const myLocationRounded = Icons.my_location_rounded;

  /// Origen: `Icons.newspaper_outlined`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  static const newspaperOutlined = Icons.newspaper_outlined;

  /// Origen: `Icons.north_east`
  ///
  /// Usos:
  /// - Configuración inicial (`features/bootstrap/screens/overlap_config_screen.dart`)
  static const northEast = Icons.north_east;

  /// Origen: `Icons.north_west`
  ///
  /// Usos:
  /// - Configuración inicial (`features/bootstrap/screens/overlap_config_screen.dart`)
  static const northWest = Icons.north_west;

  /// Origen: `Icons.notifications_active_outlined`
  ///
  /// Usos:
  /// - Ajustes: `settings_agenda_notify_desc` (`features/settings/widgets/settings_agenda_notify_row.dart`)
  static const notificationsActiveOutlined = Icons.notifications_active_outlined;

  /// Origen: `Icons.palette_outlined`
  ///
  /// Usos:
  /// - Ajustes (`features/settings/widgets/settings_general_panel.dart`)
  static const paletteOutlined = Icons.palette_outlined;

  /// Origen: `Icons.people_alt_rounded`
  ///
  /// Usos:
  /// - Ajustes (`features/settings/screens/friends_screen.dart`)
  /// - Amigos / Ver juntos: `friends_screen_title` (`widgets/dialogs/tv_friends_dialog.dart`)
  static const peopleAltRounded = Icons.people_alt_rounded;

  /// Origen: `Icons.people_outline`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_manage_friends` (`features/settings/widgets/settings_watch_party_panel.dart`)
  static const peopleOutline = Icons.people_outline;

  /// Origen: `Icons.people_outline_rounded`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `friends_section_friends` (`widgets/dialogs/tv_friends_dialog.dart`)
  static const peopleOutlineRounded = Icons.people_outline_rounded;

  /// Origen: `Symbols.person`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/player/watch_party_overlay.dart`)
  /// - TV / canales: `watch_party_friend_joined` (`features/home/areas/home_tv_area.dart`)
  static const person = Symbols.person;

  /// Origen: `Symbols.person_add`
  ///
  /// Usos:
  /// - Ajustes: `friends_add_button` (`features/settings/screens/friends_screen.dart`)
  /// - Amigos / Ver juntos: `friends_add_button` (`widgets/dialogs/tv_friends_dialog.dart`)
  static const personAdd = Symbols.person_add;

  /// Origen: `Icons.person_add_alt_1`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `friend_add_dialog_title` (`widgets/dialogs/tv_add_friend_dialog.dart`)
  static const personAddAlt1 = Icons.person_add_alt_1;

  /// Origen: `Icons.person_add_outlined`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `friends_section_requests` (`widgets/dialogs/tv_friends_dialog.dart`)
  static const personAddOutlined = Icons.person_add_outlined;

  /// Origen: `Icons.person_add_rounded`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  static const personAddRounded = Icons.person_add_rounded;

  /// Origen: `Icons.person_outline`
  ///
  /// Usos:
  /// - Ajustes: `settings_watch_party_nickname_desc` (`features/settings/widgets/settings_watch_party_panel.dart`)
  /// - Amigos / Ver juntos: `nickname_dialog_label` (`widgets/dialogs/tv_nickname_dialog.dart`)
  static const personOutline = Icons.person_outline;

  /// Origen: `Icons.person_outline_rounded`
  ///
  /// Usos:
  /// - Arcade: `friends_status_online` (`features/games/widgets/tv_arcade_select_friend_dialog.dart`)
  static const personOutlineRounded = Icons.person_outline_rounded;

  /// Origen: `Icons.person_remove_outlined`
  ///
  /// Usos:
  /// - Ajustes: `friends_delete_confirm_title` (`features/settings/screens/friends_screen.dart`)
  /// - Amigos / Ver juntos: `friends_delete_confirm_title` (`widgets/dialogs/tv_friends_dialog.dart`)
  static const personRemoveOutlined = Icons.person_remove_outlined;

  /// Origen: `Icons.person_rounded`
  ///
  /// Usos:
  /// - Ajustes (`features/settings/screens/friends_screen.dart`)
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  static const personRounded = Icons.person_rounded;

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

  /// Origen: `Icons.play_arrow_rounded`
  ///
  /// Usos:
  /// - Arcade: `arcade_action_start_game_desc` (`features/home/areas/home_arcade_area.dart`)
  static const playArrowRounded = Icons.play_arrow_rounded;

  /// Origen: `Icons.playlist_add_outlined`
  ///
  /// Usos:
  /// - Botones compartidos: `groups_name_label` (`widgets/buttons/create_group_button.dart`)
  static const playlistAddOutlined = Icons.playlist_add_outlined;

  /// Origen: `Icons.public_outlined`
  ///
  /// Usos:
  /// - Ajustes (`features/settings/screens/agenda_utc_offset_screen.dart`)
  /// - Ajustes: `settings_agenda_utc_desc` (`features/settings/widgets/settings_agenda_panel.dart`)
  static const publicOutlined = Icons.public_outlined;

  /// Origen: `Symbols.radio`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const radio = Symbols.radio;

  /// Origen: `Icons.refresh_outlined`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `mic_test_btn_rerecord` (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const refreshOutlined = Icons.refresh_outlined;

  /// Origen: `Icons.refresh_rounded`
  ///
  /// Usos:
  /// - Arcade: `arcade_btn_refresh` (`features/games/screens/arcade_games_screen.dart`)
  /// - Arcade / gamepad: `gamepad_action_reset` (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  /// - Pantalla de carga: `update_action_retry` (`features/loading/screens/loading_screen.dart`)
  static const refreshRounded = Icons.refresh_rounded;

  /// Origen: `Symbols.remote_gen`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const remoteGen = Symbols.remote_gen;

  /// Origen: `Icons.restaurant_menu_outlined`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const restaurantMenuOutlined = Icons.restaurant_menu_outlined;

  /// Origen: `Icons.schedule_outlined`
  ///
  /// Usos:
  /// - Agenda: `calendar_event_time` (`features/calendar/widgets/calendar_events_panel.dart`)
  static const scheduleOutlined = Icons.schedule_outlined;

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

  /// Origen: `Icons.search_rounded`
  ///
  /// Usos:
  /// - Clima: `weather_location_search_desc_empty` (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const searchRounded = Icons.search_rounded;

  /// Origen: `Icons.settings_remote`
  ///
  /// Usos:
  /// - Arcade: `arcade_remote_connected_p1` (`features/games/screens/arcade_screen.dart`)
  static const settingsRemote = Icons.settings_remote;

  /// Origen: `Icons.settings_remote_outlined`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_voice_test_dialog.dart`)
  /// - Inicio / menú lateral (`features/home/areas/home_settings_area.dart`)
  static const settingsRemoteOutlined = Icons.settings_remote_outlined;

  /// Origen: `Icons.south_east`
  ///
  /// Usos:
  /// - Configuración inicial (`features/bootstrap/screens/overlap_config_screen.dart`)
  static const southEast = Icons.south_east;

  /// Origen: `Icons.south_west`
  ///
  /// Usos:
  /// - Configuración inicial (`features/bootstrap/screens/overlap_config_screen.dart`)
  static const southWest = Icons.south_west;

  /// Origen: `Icons.sports_basketball_outlined`
  ///
  /// Usos:
  /// - Alias agrupado: [calendarSubNba]
  static const sportsBasketballOutlined = Icons.sports_basketball_outlined;

  /// Origen: `Icons.sports_esports_rounded`
  ///
  /// Usos:
  /// - Arcade: `arcade_prep_title` (`features/games/widgets/tv_arcade_prep_dialog.dart`)
  /// - Arcade (`features/games/widgets/tv_arcade_select_friend_dialog.dart`)
  static const sportsEsportsRounded = Icons.sports_esports_rounded;

  /// Origen: `Icons.sports_football_outlined`
  ///
  /// Usos:
  /// - Alias agrupado: [calendarSubNfl]
  static const sportsFootballOutlined = Icons.sports_football_outlined;

  /// Origen: `Icons.sports_motorsports_outlined`
  ///
  /// Usos:
  /// - Alias agrupado: [calendarSubF1]
  static const sportsMotorsportsOutlined = Icons.sports_motorsports_outlined;

  /// Origen: `Icons.sports_outlined`
  ///
  /// Usos:
  /// - Agenda: `calendar_event_time` (`features/calendar/widgets/calendar_events_panel.dart`)
  /// - Alias agrupado: [calendarSubFallback]
  static const sportsOutlined = Icons.sports_outlined;

  /// Origen: `Icons.sports_soccer_outlined`
  ///
  /// Usos:
  /// - Alias agrupado: [calendarSubLpf] / [calendarSubPremier]
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  static const sportsSoccerOutlined = Icons.sports_soccer_outlined;

  /// Origen: `Symbols.stadia_controller`
  ///
  /// Usos:
  /// - Arcade (`features/games/screens/arcade_games_screen.dart`)
  static const stadiaController = Symbols.stadia_controller;

  /// Origen: `Icons.stop`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `mic_test_btn_stop_play` (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const stop = Icons.stop;

  /// Origen: `Icons.stop_circle_outlined`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `mic_test_btn_stop` (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const stopCircleOutlined = Icons.stop_circle_outlined;

  /// Origen: `Icons.stop_rounded`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/player/watch_party_overlay.dart`)
  /// - Inicio (`features/home/widgets/tv_watch_party_header_bar.dart`)
  static const stopRounded = Icons.stop_rounded;

  /// Origen: `Symbols.bookmarks`
  ///
  /// Usos:
  /// - TV / canales: `home_panel_groups` (`features/home/areas/home_tv_area.dart`)
  static const symbolBookmarks = Symbols.bookmarks;

  /// Origen: `Symbols.chevron_right`
  ///
  /// Usos:
  /// - Ajustes (`features/settings/widgets/settings_about_panel.dart`)
  static const symbolChevronRight = Symbols.chevron_right;

  /// Origen: `Symbols.favorite`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const symbolFavorite = Symbols.favorite;

  /// Origen: `Symbols.sports_esports`
  ///
  /// Usos:
  /// - Arcade / gamepad: `gamepad_dialog_title` (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const symbolSportsEsports = Symbols.sports_esports;

  /// Origen: `Symbols.tv`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const symbolTv = Symbols.tv;

  /// Origen: `Icons.sync_outlined`
  ///
  /// Usos:
  /// - Agenda: `calendar_refresh` (`features/calendar/widgets/calendar_events_panel.dart`)
  static const syncOutlined = Icons.sync_outlined;

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

  /// Origen: `Icons.terminal_outlined`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_log_desc` (`features/settings/widgets/settings_tv_panel.dart`)
  static const terminalOutlined = Icons.terminal_outlined;

  /// Origen: `Icons.theater_comedy_outlined`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const theaterComedyOutlined = Icons.theater_comedy_outlined;

  /// Origen: `Symbols.theaters`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const theaters = Symbols.theaters;

  /// Origen: `Icons.timer_outlined`
  ///
  /// Usos:
  /// - Ajustes: `settings_agenda_snack_duration_desc` (`features/settings/widgets/settings_agenda_snack_duration_row.dart`)
  static const timerOutlined = Icons.timer_outlined;

  /// Origen: `Icons.today_outlined`
  ///
  /// Usos:
  /// - Agenda: `calendar_week_current` (`features/calendar/widgets/calendar_events_panel.dart`)
  static const todayOutlined = Icons.today_outlined;

  /// Origen: `Icons.tune_outlined`
  ///
  /// Usos:
  /// - Inicio / menú lateral (`features/home/areas/home_settings_area.dart`)
  static const tuneOutlined = Icons.tune_outlined;

  /// Origen: `Symbols.tv_displays`
  ///
  /// Usos:
  /// - TV / canales: listado de países (`widgets/cards/country_card.dart`)
  static const tvDisplays = ReiconIcons.page;

  /// Origen: `Symbols.tv_signin`
  ///
  /// Usos:
  /// - TV / canales: grupo Marcadores (`widgets/cards/group_card.dart`)
  static const tvSignin = Symbols.tv_signin;

  /// Origen: `Symbols.tv_with_assistant`
  ///
  /// Usos:
  /// - Tarjetas de listado de países/grupos (`widgets/cards/country_card.dart`)
  static const tvWithAssistant = Symbols.tv_with_assistant;

  /// Origen: `Symbols.tv_guide`
  ///
  /// Usos:
  /// - Ajustes: `settings_about_channels_loaded` (`features/settings/widgets/settings_about_panel.dart`)
  static const tvGuide = Symbols.tv_guide;

  /// Origen: `Icons.tv_rounded`
  ///
  /// Usos:
  /// - Ajustes (`features/settings/screens/friends_screen.dart`)
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  static const tvRounded = Icons.tv_rounded;

  /// Origen: `Icons.two_wheeler_outlined`
  ///
  /// Usos:
  /// - Alias agrupado: [calendarSubMotogp]
  static const twoWheelerOutlined = Icons.two_wheeler_outlined;

  /// Origen: `Symbols.videogame_asset_off`
  ///
  /// Usos:
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const videogameAssetOff = Symbols.videogame_asset_off;

  /// Origen: `Icons.videogame_asset_off_outlined`
  ///
  /// Usos:
  /// - Arcade / gamepad (`widgets/dialogs/tv_gamepad_config_dialog.dart`)
  static const videogameAssetOffOutlined = Icons.videogame_asset_off_outlined;

  /// Origen: `Symbols.visibility`
  ///
  /// Usos:
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  static const visibility = Symbols.visibility;

  /// Origen: `Symbols.voice_selection`
  ///
  /// Usos:
  /// - Ajustes: `settings_tv_watch_party_desc` (`features/settings/widgets/settings_watch_party_panel.dart`)
  /// - Amigos / Ver juntos (`widgets/player/watch_party_overlay.dart`)
  /// - Inicio (`features/home/widgets/tv_watch_party_header_bar.dart`)
  static const voiceSelection = Symbols.voice_selection;

  /// Origen: `Icons.volume_up`
  ///
  /// Usos:
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const volumeUp = Icons.volume_up;

  /// Origen: `Icons.volume_up_outlined`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `mic_test_btn_stop_play` (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const volumeUpOutlined = Icons.volume_up_outlined;

  /// Origen: `Icons.volume_off_outlined`
  ///
  /// Usos:
  /// - Ajustes Generales: desactivar audio de interfaz
  ///   (`features/settings/widgets/settings_general_panel.dart`)
  static const volumeOffOutlined = Icons.volume_off_outlined;

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

  /// Origen: `Icons.warning_amber_rounded`
  ///
  /// Usos:
  /// - Amigos / Ver juntos: `mic_test_empty_desc` (`widgets/dialogs/tv_voice_test_dialog.dart`)
  static const warningAmberRounded = Icons.warning_amber_rounded;

  /// Origen: `Icons.wb_sunny_outlined`
  ///
  /// Usos:
  /// - Inicio (`features/home/widgets/tv_vertical_clock_pill.dart`)
  static const wbSunnyOutlined = Icons.wb_sunny_outlined;

  /// Origen: `Icons.wifi_off_rounded`
  ///
  /// Usos:
  /// - Pantalla de carga: `loading_error_title` (`features/loading/screens/loading_screen.dart`)
  static const wifiOffRounded = Icons.wifi_off_rounded;
}
