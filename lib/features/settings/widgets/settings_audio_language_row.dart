import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/settings/widgets/settings_option_row.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_icons.dart';

/// "Idioma del audio" de películas y series: uno para todo, en vez de
/// cambiarlo en cada película.
class SettingsAudioLanguageRow extends StatelessWidget {
  final FocusNode focusNode;
  final MovieAudioLanguage selected;
  final ValueChanged<MovieAudioLanguage> onChanged;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const SettingsAudioLanguageRow({
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
    MovieAudioLanguage.spanish: LocaleKeys.settings_movies_audio_spanish,
    MovieAudioLanguage.english: LocaleKeys.settings_movies_audio_english,
    MovieAudioLanguage.original: LocaleKeys.settings_movies_audio_original,
  };

  @override
  Widget build(BuildContext context) {
    return SettingsOptionRow<MovieAudioLanguage>(
      focusNode: focusNode,
      label: LocaleKeys.settings_movies_audio_language.tr(),
      description: LocaleKeys.settings_movies_audio_language_desc.tr(),
      icon: MoaiIcons.vodAudio,
      options: MovieAudioLanguage.values,
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
