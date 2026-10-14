import 'package:moai3/config/app_config.dart';

/// Índices de paneles del acordeón TV (Explorar).
abstract final class TvPanelLayout {
  /// Log visible solo con DEBUG_MODE y preferencia de usuario.
  static bool hasLogPanel(bool showTvLog) =>
      AppConfig.debugMode && showTvLog;

  static int panelCount(bool showTvLog) => hasLogPanel(showTvLog) ? 4 : 3;

  static int logPanelIndex(bool showTvLog) => hasLogPanel(showTvLog) ? 0 : -1;

  static int countryPanelIndex(bool showTvLog) =>
      hasLogPanel(showTvLog) ? 1 : 0;

  static int categoryPanelIndex(bool showTvLog) =>
      hasLogPanel(showTvLog) ? 2 : 1;

  static int channelPanelIndex(bool showTvLog) =>
      hasLogPanel(showTvLog) ? 3 : 2;

  static bool isLogPanel(int index, bool showTvLog) =>
      hasLogPanel(showTvLog) && index == logPanelIndex(showTvLog);

  static bool isCountryPanel(int index, bool showTvLog) =>
      index == countryPanelIndex(showTvLog);

  static bool isCategoryPanel(int index, bool showTvLog) =>
      index == categoryPanelIndex(showTvLog);

  static bool isChannelPanel(int index, bool showTvLog) =>
      index == channelPanelIndex(showTvLog);

  /// Conserva el panel lógico al activar/desactivar el panel de log.
  static int remapPanelIndex(int oldIndex, bool oldShowTvLog, bool newShowTvLog) {
    if (oldShowTvLog == newShowTvLog) return oldIndex;
    late final int next;
    if (isLogPanel(oldIndex, oldShowTvLog)) {
      next = hasLogPanel(newShowTvLog)
          ? logPanelIndex(newShowTvLog)
          : countryPanelIndex(newShowTvLog);
    } else if (isCountryPanel(oldIndex, oldShowTvLog)) {
      next = countryPanelIndex(newShowTvLog);
    } else if (isCategoryPanel(oldIndex, oldShowTvLog)) {
      next = categoryPanelIndex(newShowTvLog);
    } else if (isChannelPanel(oldIndex, oldShowTvLog)) {
      next = channelPanelIndex(newShowTvLog);
    } else {
      next = countryPanelIndex(newShowTvLog);
    }
    final max = panelCount(newShowTvLog) - 1;
    if (next < 0) return 0;
    if (next > max) return max;
    return next;
  }
}

