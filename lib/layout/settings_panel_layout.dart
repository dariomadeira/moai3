/// Índices del acordeón de Ajustes (igual que moaiSmart).
abstract final class SettingsPanelLayout {
  static const int panelCount = 3;

  static const int configTvPanelIndex = 0;
  static const int configGeneralPanelIndex = 1;
  static const int aboutPanelIndex = 2;

  static bool isConfigTvPanel(int index) => index == configTvPanelIndex;
  static bool isConfigGeneralPanel(int index) =>
      index == configGeneralPanelIndex;
  static bool isAboutPanel(int index) => index == aboutPanelIndex;
}

