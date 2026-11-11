import 'package:moai3/features/movies/movie_player_format.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/settings/widgets/settings_option_row.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_icons.dart';

/// "Tamaño de los subtítulos" de películas y series.
class SettingsSubtitleSizeRow extends StatelessWidget {
  final FocusNode focusNode;
  final MovieSubtitleSize selected;
  final ValueChanged<MovieSubtitleSize> onChanged;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;
  final Color? iconColor;

  const SettingsSubtitleSizeRow({
    super.key,
    required this.focusNode,
    required this.selected,
    required this.onChanged,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsOptionRow<MovieSubtitleSize>(
      focusNode: focusNode,
      label: LocaleKeys.settings_movies_subtitle_size.tr(),
      description: LocaleKeys.settings_movies_subtitle_size_desc.tr(),
      icon: MoaiIcons.vodSubtitleSize,
      iconColor: iconColor,
      options: MovieSubtitleSize.values,
      selected: selected,
      onChanged: onChanged,
      labelBuilder: subtitleSizeLabel,
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
    );
  }
}
