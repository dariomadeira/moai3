import 'package:moai3/layout/tv_panel_layout.dart';

/// Grafo de foco TV: restaura foco según panel activo al salir del rail.
class TvFocusController {
  void restoreAfterRailRight({
    required int activePanelIndex,
    required bool showTvLog,
    required void Function() focusDebug,
    required void Function() focusCountry,
    required void Function() focusCategory,
    required void Function() focusChannel,
    required void Function() focusSearch,
  }) {
    if (TvPanelLayout.isLogPanel(activePanelIndex, showTvLog)) {
      focusDebug();
    } else if (TvPanelLayout.isSearchPanel(activePanelIndex, showTvLog)) {
      focusSearch();
    } else if (TvPanelLayout.isCountryPanel(activePanelIndex, showTvLog)) {
      focusCountry();
    } else if (TvPanelLayout.isCategoryPanel(activePanelIndex, showTvLog)) {
      focusCategory();
    } else {
      focusChannel();
    }
  }
}

