/// Índices del acordeón de Ajustes (igual que moaiSmart).
abstract final class SettingsPanelLayout {
  static const int panelCount = 5;

  static const int configTvPanelIndex = 0;
  static const int configAgendaPanelIndex = 1;
  static const int watchPartyPanelIndex = 2;
  static const int configGeneralPanelIndex = 3;
  static const int aboutPanelIndex = 4;

  static bool isConfigTvPanel(int index) => index == configTvPanelIndex;
  static bool isConfigAgendaPanel(int index) => index == configAgendaPanelIndex;
  static bool isWatchPartyPanel(int index) => index == watchPartyPanelIndex;
  static bool isConfigGeneralPanel(int index) =>
      index == configGeneralPanelIndex;
  static bool isAboutPanel(int index) => index == aboutPanelIndex;
}

