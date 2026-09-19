import 'package:moai3/config/app_config.dart';

/// Índices de paneles del acordeón TV (Explorar).
abstract final class TvPanelLayout {
  /// Log visible solo con DEBUG_MODE y preferencia de usuario.
  static bool hasLogPanel(bool showTvLog) =>
      AppConfig.debugMode && showTvLog;

  static int panelCount(bool showTvLog) => hasLogPanel(showTvLog) ? 5 : 4;

  static int logPanelIndex(bool showTvLog) => hasLogPanel(showTvLog) ? 0 : -1;

  static int searchPanelIndex(bool showTvLog) =>
      hasLogPanel(showTvLog) ? 1 : 0;

  static int countryPanelIndex(bool showTvLog) =>
      hasLogPanel(showTvLog) ? 2 : 1;

  static int categoryPanelIndex(bool showTvLog) =>
      hasLogPanel(showTvLog) ? 3 : 2;

  static int channelPanelIndex(bool showTvLog) =>
      hasLogPanel(showTvLog) ? 4 : 3;

  static bool isLogPanel(int index, bool showTvLog) =>
      hasLogPanel(showTvLog) && index == logPanelIndex(showTvLog);

  static bool isSearchPanel(int index, bool showTvLog) =>
      index == searchPanelIndex(showTvLog);

  static bool isCountryPanel(int index, bool showTvLog) =>
      index == countryPanelIndex(showTvLog);

  static bool isCategoryPanel(int index, bool showTvLog) =>
      index == categoryPanelIndex(showTvLog);

  static bool isChannelPanel(int index, bool showTvLog) =>
      index == channelPanelIndex(showTvLog);
}

