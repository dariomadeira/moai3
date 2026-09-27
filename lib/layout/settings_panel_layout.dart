/// Índices del acordeón de Ajustes (igual que moaiSmart).
abstract final class SettingsPanelLayout {
  static const int panelCount = 4;

  static const int configTvPanelIndex = 0;
  static const int configAgendaPanelIndex = 1;
  static const int configGeneralPanelIndex = 2;
  static const int aboutPanelIndex = 3;

  static bool isConfigTvPanel(int index) => index == configTvPanelIndex;
  static bool isConfigGeneralPanel(int index) =>
      index == configGeneralPanelIndex;
  static bool isConfigAgendaPanel(int index) => index == configAgendaPanelIndex;
  static bool isAboutPanel(int index) => index == aboutPanelIndex;
}

