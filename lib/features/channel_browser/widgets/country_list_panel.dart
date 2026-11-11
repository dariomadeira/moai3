import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/channel_browser/country_flag_assets.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/cards/tv_group_tile.dart';
import 'package:moai3/widgets/lists/tv_group_list_panel.dart';

typedef CountryListPanelState = TvGroupListPanelState<String>;

/// Panel Grupos (países): el mismo diseño que Categorías y Marcadores, con
/// la bandera de cada país.
class CountryListPanel extends TvGroupListPanel<String> {
  final List<String> countries;
  final Map<String, String> countryFlags;
  final String selectedCountry;
  final ValueChanged<String> onSelect;
  final VoidCallback onLongPress;

  /// Grupo del canal sintonizado (el del visor): sólo ese lleva el check,
  /// no el que se va eligiendo al navegar. Null: ninguno.
  final String? tunedCountry;

  /// Mensaje del estado vacío; por defecto "sin grupos". Se usa para mostrar
  /// un error de carga de plugins.
  final String? emptyMessageOverride;

  const CountryListPanel({
    super.key,
    required this.countries,
    this.countryFlags = const {},
    required this.selectedCountry,
    required this.onSelect,
    required this.onLongPress,
    super.onFocusUp,
    this.tunedCountry,
    String? emptyMessage,
  }) : emptyMessageOverride = emptyMessage;

  @override
  List<String> get items => countries;

  @override
  int get selectedIndex => countries.indexOf(selectedCountry);

  @override
  bool selectionChanged(CountryListPanel old) =>
      old.selectedCountry != selectedCountry;

  @override
  String get title => LocaleKeys.browser_country_title.tr();

  @override
  String get subtitle => LocaleKeys.browser_country_subtitle.tr();

  @override
  IconData get emptyIcon => MoaiIcons.tvAccordionGrupos;

  @override
  String get emptyMessage =>
      emptyMessageOverride ?? LocaleKeys.browser_countries_empty.tr();

  @override
  String get debugName => 'country';

  @override
  bool get focusOnMount => false;

  @override
  Widget buildTile(
    BuildContext context,
    String country,
    FocusNode focusNode,
    VoidCallback onKeyUp,
    VoidCallback onKeyDown,
  ) => TvGroupTile(
    key: ValueKey('country-$country'),
    label: country,
    icon: MoaiIcons.tvCountryItem,
    leading: CountryFlagAssets.leadingFor(
      country,
      flagUrl: countryFlags[country],
    ),
    isSelected: tunedCountry == country,
    focusNode: focusNode,
    onLongPress: onLongPress,
    onKeyUp: onKeyUp,
    onKeyDown: onKeyDown,
    onTap: () => onSelect(country),
  );
}
