import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardián del modo oscuro: los colores fijos (`Colors.white`,
/// `Colors.black…`, `Color(0x…)`) no siguen al tema, así que no pueden
/// aparecer nuevos. Un color que depende del tema va en el tema o en
/// `MoaiPalette`; uno que va siempre igual (sobre video o una imagen, de
/// marca, de datos) se anota acá a mano, con el número nuevo.
///
/// La lista es la foto del 2026-11-10, antes del modo oscuro. Al pasar
/// colores al tema el número de un archivo baja: se baja acá también, así
/// no se vuelven a meter.
const Map<String, int> _allowed = {
  'lib/features/bootstrap/screens/overlap_config_screen.dart': 1,
  'lib/features/calendar/widgets/calendar_events_panel.dart': 1,
  'lib/features/discounts/discount_format.dart': 4,
  'lib/features/discounts/widgets/discount_dialogs.dart': 4,
  'lib/features/discounts/widgets/discounts_week_panel.dart': 1,
  'lib/features/games/screens/arcade_screen.dart': 4,
  'lib/features/games/widgets/arcade_controller_overlay.dart': 6,
  'lib/features/games/widgets/arcade_view_container.dart': 1,
  'lib/features/games/widgets/tv_arcade_prep_dialog.dart': 1,
  'lib/features/home/widgets/alphabet_jump_panel.dart': 1,
  'lib/features/home/widgets/home_arcade_card.dart': 1,
  'lib/features/home/widgets/home_clock.dart': 8,
  'lib/features/home/widgets/home_continue_card.dart': 1,
  'lib/features/home/widgets/home_discounts_card.dart': 1,
  'lib/features/home/widgets/home_friend_requests_card.dart': 1,
  'lib/features/home/widgets/home_friends_card.dart': 2,
  'lib/features/home/widgets/home_recommendations_card.dart': 1,
  'lib/features/home/widgets/home_trailers_card.dart': 1,
  'lib/features/home/widgets/home_watchlist_big_card.dart': 1,
  'lib/features/home/widgets/tv_movie_card.dart': 6,
  'lib/features/home/widgets/tv_vertical_nav_rail.dart': 3,
  'lib/features/loading/screens/loading_screen.dart': 1,
  'lib/features/movies/screens/movie_detail_screen.dart': 3,
  'lib/features/movies/screens/movie_player_screen.dart': 9,
  'lib/features/movies/widgets/movie_detail_parts.dart': 10,
  'lib/features/movies/widgets/movie_hero_card.dart': 8,
  'lib/features/movies/widgets/movie_player_osd.dart': 21,
  'lib/features/movies/widgets/tv_movie_hero_card.dart': 4,
  'lib/features/search/widgets/search_panel.dart': 1,
  'lib/features/settings/screens/accent_color_screen.dart': 2,
  'lib/features/settings/widgets/settings_widgets.dart': 6,
  'lib/features/settings/widgets/tv_option_selector.dart': 5,
  'lib/state/calendar_provider.dart': 6,
  'lib/theme/moai_accent_colors.dart': 11,
  'lib/theme/moai_focus_style.dart': 1,
  'lib/utils/image_tint.dart': 1,
  'lib/widgets/buttons/moai_pill_button.dart': 5,
  'lib/widgets/buttons/tv_back_pill.dart': 1,
  'lib/widgets/buttons/tv_icon_action_button.dart': 2,
  'lib/widgets/buttons/tv_install_pill.dart': 3,
  'lib/widgets/cards/alphabet_letter_card.dart': 1,
  'lib/widgets/cards/channel_source_tag.dart': 7,
  'lib/widgets/dialogs/plugin_update_dialog.dart': 1,
  'lib/widgets/dialogs/tv_agenda_time_zone_dialog.dart': 1,
  'lib/widgets/dialogs/tv_dialog.dart': 1,
  'lib/widgets/dialogs/tv_friends/friend_tile.dart': 1,
  'lib/widgets/dialogs/tv_gamepad/gamepad_config_columns.dart': 10,
  'lib/widgets/dialogs/tv_gamepad/squircle_button.dart': 2,
  'lib/widgets/dialogs/tv_pin/tv_pin_views.dart': 2,
  'lib/widgets/dialogs/tv_pin_dialog.dart': 4,
  'lib/widgets/dialogs/tv_voice_test/tv_voice_test_views.dart': 3,
  'lib/widgets/dialogs/update_dialog.dart': 3,
  'lib/widgets/feedback/moai_snackbar.dart': 1,
  'lib/widgets/player/viewer_error_display.dart': 4,
  'lib/widgets/player/watch_party_overlay.dart': 4,
  'lib/widgets/tv_common/friend_avatar.dart': 1,
  'lib/widgets/tv_common/moai_count_badge.dart': 3,
  'lib/widgets/tv_common/moai_glass.dart': 12,
  'lib/widgets/tv_common/moai_status_tag.dart': 5,
  'lib/widgets/tv_common/tv_m3.dart': 1,
  'lib/widgets/tv_common/tv_meta_pill.dart': 2,
  'lib/widgets/tv_common/tv_panel_header.dart': 1,
  'lib/widgets/tv_common/tv_value_chip.dart': 4,
  'lib/widgets/tv_input/tv_on_screen_keyboard.dart': 2,
  'lib/widgets/tv_input/tv_text_input_sheet.dart': 1,
  'lib/widgets/week/tv_week_grid.dart': 4,
};

/// La casa de los colores de cada modo: acá van, no se cuentan.
const _themeHome = {'lib/theme/moai_theme.dart', 'lib/theme/moai_palette.dart'};

final _hardcoded = RegExp(r'Colors\.(?:white|black)\w*|Color\(0x');

void main() {
  final counts = <String, int>{
    for (final e in Directory('lib').listSync(recursive: true))
      if (e is File && e.path.endsWith('.dart'))
        e.path.replaceAll(r'\', '/'): _hardcoded
            .allMatches(e.readAsStringSync())
            .length,
  }..removeWhere((path, _) => _themeHome.contains(path));

  test('no hay colores fijos nuevos', () {
    final grown = [
      for (final MapEntry(key: path, value: n) in counts.entries)
        if (n > (_allowed[path] ?? 0))
          '$path: $n (permitidos: ${_allowed[path] ?? 0})',
    ];
    expect(
      grown,
      isEmpty,
      reason:
          'Colores fijos nuevos: no siguen al modo oscuro. Usar el tema '
          '(scheme.*) o MoaiPalette; si de verdad va siempre igual, subir '
          'el número en test/hardcoded_colors_test.dart.',
    );
  });

  test('la lista está al día (se bajó al sacar colores)', () {
    final stale = [
      for (final MapEntry(key: path, value: allowed) in _allowed.entries)
        if ((counts[path] ?? 0) < allowed)
          '$path: ${counts[path] ?? 0} (lista: $allowed)',
    ];
    expect(
      stale,
      isEmpty,
      reason: 'Bajar estos números en test/hardcoded_colors_test.dart.',
    );
  });
}
