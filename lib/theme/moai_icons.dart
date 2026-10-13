import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Catálogo único de iconos de Moai.
///
/// Cada constante apunta a un [IconData] concreto. El comentario describe
/// en qué zona de la UI se usa (y la ruta del archivo). Cambiar el valor
/// aquí actualiza todos los lugares que referencian la constante.
abstract final class MoaiIcons {
  MoaiIcons._();

  /// Origen: `Symbols.adaptive_audio_mic`
  ///
  /// Usos:
  /// - Inicio / menú lateral (`features/home/areas/home_settings_area.dart`)
  static const adaptiveAudioMic = Symbols.adaptive_audio_mic;

  /// Origen: `Icons.add_rounded`
  ///
  /// Usos:
  /// - Botones compartidos (`widgets/buttons/create_group_button.dart`)
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
  /// - TV / canales: `home_tab_groups` (`features/home/widgets/tv_tab_bar.dart`)
  static const bookmarks = Icons.bookmarks;

  /// Origen: `Icons.bookmarks_outlined`
  ///
  /// Usos:
  /// - TV / canales: `browser_groups_empty` (`features/groups/widgets/group_list_panel.dart`)
  /// - TV / canales: `home_tab_groups` (`features/home/widgets/tv_tab_bar.dart`)
  static const bookmarksOutlined = Icons.bookmarks_outlined;

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
  /// - Agenda (`features/home/areas/home_calendar_area.dart`)
  static const calendarAddOn = Symbols.calendar_add_on;

  /// Origen: `Icons.calendar_month`
  ///
  /// Usos:
  /// - Inicio / menú lateral: `home_rail_tv_title` (`features/home/widgets/navigation_rail_section.dart`)
  static const calendarMonth = Icons.calendar_month;

  /// Origen: `Icons.calendar_month_outlined`
  ///
  /// Usos:
  /// - Agenda (`features/calendar/widgets/calendar_events_panel.dart`)
  /// - Agenda (`features/home/areas/home_calendar_area.dart`)
  /// - Inicio / menú lateral (`features/home/areas/home_settings_area.dart`)
  /// - Inicio / menú lateral: `home_rail_tv_title` (`features/home/widgets/navigation_rail_section.dart`)
  static const calendarMonthOutlined = Icons.calendar_month_outlined;

  /// Origen: `Icons.cancel_outlined`
  ///
  /// Usos:
  /// - TV / canales (`features/search/widgets/search_panel.dart`)
  static const cancelOutlined = Icons.cancel_outlined;

  /// Origen: `Icons.category_outlined`
  ///
  /// Usos:
  /// - TV / canales: `browser_categories_empty` (`features/channel_browser/widgets/category_list_panel.dart`)
  /// - TV / canales (`features/home/areas/home_tv_area.dart`)
  /// - TV / canales (`features/home/widgets/channel_viewer_header.dart`)
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
  /// - Ajustes: `settings_general_skip_catalog_desc` (`features/settings/widgets/settings_general_panel.dart`)
  static const cloudOffOutlined = Icons.cloud_off_outlined;

  /// Origen: `Icons.cloud_outlined`
  ///
  /// Usos:
  /// - Ajustes: `settings_general_weather_title` (`features/settings/widgets/settings_general_panel.dart`)
  static const cloudOutlined = Icons.cloud_outlined;

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
  static const deleteOutlineRounded = Icons.delete_outline_rounded;

  /// Origen: `Icons.delete_sweep_outlined`
  ///
  /// Usos:
  /// - Botones compartidos: `favorites_clear_title` (`widgets/buttons/clear_favorites_button.dart`)
  static const deleteSweepOutlined = Icons.delete_sweep_outlined;

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
  /// - Agenda (`state/calendar_provider.dart`)
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
  /// - TV / canales: `home_tab_explore` (`features/home/widgets/tv_tab_bar.dart`)
  static const explore = Icons.explore;

  /// Origen: `Icons.explore_outlined`
  ///
  /// Usos:
  /// - TV / canales: `home_tab_explore` (`features/home/widgets/tv_tab_bar.dart`)
  /// - TV / canales (`features/search/widgets/search_panel.dart`)
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
  /// - TV / canales (`features/home/widgets/channel_viewer_header.dart`)
  static const extensionOutlined = Icons.extension_outlined;

  /// Origen: `Icons.favorite`
  ///
  /// Usos:
  /// - Botones compartidos (`widgets/buttons/favorite_button.dart`)
  static const favorite = Icons.favorite;

  /// Origen: `Icons.favorite_outline`
  ///
  /// Usos:
  /// - Botones compartidos (`widgets/buttons/favorite_button.dart`)
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
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
  /// - TV / canales (`features/home/areas/home_tv_area.dart`)
  /// - TV / canales (`features/home/widgets/channel_viewer_header.dart`)
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
  static const keyboard = Icons.keyboard;

  /// Origen: `Icons.keyboard_alt_outlined`
  ///
  /// Usos:
  /// - Componentes TV compartidos (`widgets/tv_input/tv_text_field.dart`)
  /// - TV / canales: `search_field_label` (`features/search/widgets/search_panel.dart`)
  static const keyboardAltOutlined = Icons.keyboard_alt_outlined;

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
  /// - TV / canales: `home_panel_groups` (`features/home/areas/home_tv_area.dart`)
  /// - TV / canales (`features/home/widgets/empty_viewer_panel.dart`)
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
  static const movie = Symbols.movie;

  /// Origen: `Icons.movie_outlined`
  ///
  /// Usos:
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
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
  /// - TV / canales: `home_tab_search` (`features/home/widgets/tv_tab_bar.dart`)
  static const search = Icons.search;

  /// Origen: `Icons.search_outlined`
  ///
  /// Usos:
  /// - TV / canales: `home_tab_search` (`features/home/widgets/tv_tab_bar.dart`)
  static const searchOutlined = Icons.search_outlined;

  /// Origen: `Icons.search_rounded`
  ///
  /// Usos:
  /// - Clima: `weather_location_search_desc_empty` (`widgets/dialogs/tv_weather_location_dialog.dart`)
  static const searchRounded = Icons.search_rounded;

  /// Origen: `Icons.settings`
  ///
  /// Usos:
  /// - Inicio / menú lateral: `home_rail_arcade_title` (`features/home/widgets/navigation_rail_section.dart`)
  static const settings = Icons.settings;

  /// Origen: `Icons.settings_outlined`
  ///
  /// Usos:
  /// - Inicio / menú lateral: `home_rail_arcade_title` (`features/home/widgets/navigation_rail_section.dart`)
  static const settingsOutlined = Icons.settings_outlined;

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
  /// - Agenda (`state/calendar_provider.dart`)
  static const sportsBasketballOutlined = Icons.sports_basketball_outlined;

  /// Origen: `Icons.sports_esports`
  ///
  /// Usos:
  /// - Arcade (`features/games/screens/arcade_games_screen.dart`)
  /// - Arcade: `arcade_remote_connected_p1` (`features/games/screens/arcade_screen.dart`)
  /// - Inicio: `arcade_invite_received` (`features/home/screens/home_screen.dart`)
  /// - Inicio / menú lateral: `home_rail_calendar_title` (`features/home/widgets/navigation_rail_section.dart`)
  static const sportsEsports = Icons.sports_esports;

  /// Origen: `Icons.sports_esports_outlined`
  ///
  /// Usos:
  /// - Arcade: `arcade_empty_installed_msg` (`features/games/screens/arcade_games_screen.dart`)
  /// - Arcade: `arcade_panel_title` (`features/home/areas/home_arcade_area.dart`)
  /// - Inicio / menú lateral: `home_rail_calendar_title` (`features/home/widgets/navigation_rail_section.dart`)
  static const sportsEsportsOutlined = Icons.sports_esports_outlined;

  /// Origen: `Icons.sports_esports_rounded`
  ///
  /// Usos:
  /// - Arcade: `arcade_prep_title` (`features/games/widgets/tv_arcade_prep_dialog.dart`)
  /// - Arcade (`features/games/widgets/tv_arcade_select_friend_dialog.dart`)
  static const sportsEsportsRounded = Icons.sports_esports_rounded;

  /// Origen: `Icons.sports_football_outlined`
  ///
  /// Usos:
  /// - Agenda (`state/calendar_provider.dart`)
  static const sportsFootballOutlined = Icons.sports_football_outlined;

  /// Origen: `Icons.sports_motorsports_outlined`
  ///
  /// Usos:
  /// - Agenda (`state/calendar_provider.dart`)
  static const sportsMotorsportsOutlined = Icons.sports_motorsports_outlined;

  /// Origen: `Icons.sports_outlined`
  ///
  /// Usos:
  /// - Agenda: `calendar_event_time` (`features/calendar/widgets/calendar_events_panel.dart`)
  /// - Agenda (`state/calendar_provider.dart`)
  static const sportsOutlined = Icons.sports_outlined;

  /// Origen: `Icons.sports_soccer_outlined`
  ///
  /// Usos:
  /// - Agenda (`state/calendar_provider.dart`)
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
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

  /// Origen: `Icons.tv`
  ///
  /// Usos:
  /// - Inicio / menú lateral: `home_rail_tv_title` (`features/home/widgets/navigation_rail_section.dart`)
  static const tv = Icons.tv;

  /// Origen: `Symbols.tv_displays`
  ///
  /// Usos:
  /// - Tarjetas de listado (`widgets/cards/country_card.dart`)
  static const tvDisplays = Symbols.tv_displays;

  /// Origen: `Symbols.tv_guide`
  ///
  /// Usos:
  /// - Ajustes: `settings_about_channels_loaded` (`features/settings/widgets/settings_about_panel.dart`)
  static const tvGuide = Symbols.tv_guide;

  /// Origen: `Icons.tv_outlined`
  ///
  /// Usos:
  /// - Agenda: `calendar_event_broadcaster` (`features/calendar/widgets/calendar_events_panel.dart`)
  /// - Categorías de canales (mapa por nombre) (`widgets/cards/category_card.dart`)
  /// - Grupos (mapa por clave) (`widgets/cards/group_card.dart`)
  /// - Inicio / menú lateral: `home_rail_tv_title` (`features/home/widgets/navigation_rail_section.dart`)
  /// - Tarjetas de listado (`widgets/cards/tv_list_card_leading_logo.dart`)
  static const tvOutlined = Icons.tv_outlined;

  /// Origen: `Icons.tv_rounded`
  ///
  /// Usos:
  /// - Ajustes (`features/settings/screens/friends_screen.dart`)
  /// - Amigos / Ver juntos (`widgets/dialogs/tv_friends_dialog.dart`)
  static const tvRounded = Icons.tv_rounded;

  /// Origen: `Icons.two_wheeler_outlined`
  ///
  /// Usos:
  /// - Agenda (`state/calendar_provider.dart`)
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
