/// Índices del acordeón de Ajustes (igual que moaiSmart + panel películas/series).
abstract final class SettingsPanelLayout {
  static const int panelCount = 6;

  static const int configTvPanelIndex = 0;
  static const int configMoviesSeriesPanelIndex = 1;
  static const int configAgendaPanelIndex = 2;
  static const int watchPartyPanelIndex = 3;
  static const int configGeneralPanelIndex = 4;
  static const int aboutPanelIndex = 5;

  static bool isConfigTvPanel(int index) => index == configTvPanelIndex;
  static bool isConfigMoviesSeriesPanel(int index) =>
      index == configMoviesSeriesPanelIndex;
  static bool isConfigAgendaPanel(int index) => index == configAgendaPanelIndex;
  static bool isWatchPartyPanel(int index) => index == watchPartyPanelIndex;
  static bool isConfigGeneralPanel(int index) =>
      index == configGeneralPanelIndex;
  static bool isAboutPanel(int index) => index == aboutPanelIndex;
}
