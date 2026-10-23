import 'package:moai3/config/app_config.dart';

/// Paneles del acordeón Explorar de TV.
enum TvExplorePanel { log, country, category, channel }

/// Posición de cada [TvExplorePanel] en el acordeón: el log solo aparece con
/// DEBUG_MODE y la preferencia del usuario, y corre al resto una posición.
abstract final class TvPanelLayout {
  static bool hasLogPanel(bool showTvLog) => AppConfig.debugMode && showTvLog;

  /// Paneles visibles, en orden.
  static List<TvExplorePanel> panels(bool showTvLog) => hasLogPanel(showTvLog)
      ? TvExplorePanel.values
      : const [
          TvExplorePanel.country,
          TvExplorePanel.category,
          TvExplorePanel.channel,
        ];

  /// El panel tal como se ve: si el log está oculto, Países.
  static TvExplorePanel visible(TvExplorePanel panel, bool showTvLog) =>
      panel == TvExplorePanel.log && !hasLogPanel(showTvLog)
      ? TvExplorePanel.country
      : panel;

  static int indexOf(TvExplorePanel panel, bool showTvLog) =>
      panels(showTvLog).indexOf(visible(panel, showTvLog));

  static TvExplorePanel panelAt(int index, bool showTvLog) {
    final list = panels(showTvLog);
    return list[index.clamp(0, list.length - 1)];
  }
}
