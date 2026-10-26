import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/settings/widgets/settings_option_row.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_icons.dart';

/// "Subtítulos" de películas y series: apagados o en un idioma, para todo.
class SettingsSubtitleLanguageRow extends StatelessWidget {
  final FocusNode focusNode;
  final MovieSubtitleLanguage selected;
  final ValueChanged<MovieSubtitleLanguage> onChanged;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const SettingsSubtitleLanguageRow({
    super.key,
    required this.focusNode,
    required this.selected,
    required this.onChanged,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  static const _labelKeys = {
    MovieSubtitleLanguage.off: LocaleKeys.settings_movies_subtitles_off,
    MovieSubtitleLanguage.spanish: LocaleKeys.settings_movies_audio_spanish,
    MovieSubtitleLanguage.english: LocaleKeys.settings_movies_audio_english,
  };

  @override
  Widget build(BuildContext context) {
    return SettingsOptionRow<MovieSubtitleLanguage>(
      focusNode: focusNode,
      label: LocaleKeys.settings_movies_subtitles.tr(),
      description: LocaleKeys.settings_movies_subtitles_desc.tr(),
      icon: MoaiIcons.vodSubtitles,
      options: MovieSubtitleLanguage.values,
      selected: selected,
      onChanged: onChanged,
      labelBuilder: (option) => _labelKeys[option]!.tr(),
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
    );
  }
}
