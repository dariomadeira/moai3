import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/config/app_config.dart';
import 'package:moai3/focus/tv_panel_layout.dart';

void main() {
  group('TvPanelLayout', () {
    tearDown(() {
      AppConfig.debugModeOverride = null;
    });

    test('sin debug: tres paneles (Países, Categorías, Canales)', () {
      AppConfig.debugModeOverride = false;
      const showTvLog = true;
      expect(TvPanelLayout.panels(showTvLog), [
        TvExplorePanel.country,
        TvExplorePanel.category,
        TvExplorePanel.channel,
      ]);
      expect(TvPanelLayout.indexOf(TvExplorePanel.country, showTvLog), 0);
      expect(TvPanelLayout.indexOf(TvExplorePanel.channel, showTvLog), 2);
      expect(TvPanelLayout.panelAt(1, showTvLog), TvExplorePanel.category);
    });

    test('con debug y log: el log va primero y corre al resto', () {
      AppConfig.debugModeOverride = true;
      const showTvLog = true;
      expect(TvPanelLayout.panels(showTvLog), TvExplorePanel.values);
      expect(TvPanelLayout.indexOf(TvExplorePanel.log, showTvLog), 0);
      expect(TvPanelLayout.indexOf(TvExplorePanel.country, showTvLog), 1);
      expect(TvPanelLayout.indexOf(TvExplorePanel.channel, showTvLog), 3);
      expect(TvPanelLayout.panelAt(0, showTvLog), TvExplorePanel.log);
    });

    test('con debug pero log desactivado: tres paneles', () {
      AppConfig.debugModeOverride = true;
      const showTvLog = false;
      expect(TvPanelLayout.panels(showTvLog).length, 3);
      expect(TvPanelLayout.panelAt(0, showTvLog), TvExplorePanel.country);
    });

    test('el log oculto se ve como Países', () {
      AppConfig.debugModeOverride = false;
      expect(
        TvPanelLayout.visible(TvExplorePanel.log, true),
        TvExplorePanel.country,
      );
      expect(TvPanelLayout.indexOf(TvExplorePanel.log, true), 0);
      expect(
        TvPanelLayout.visible(TvExplorePanel.category, true),
        TvExplorePanel.category,
      );
    });

    test('panelAt acota índices fuera de rango', () {
      AppConfig.debugModeOverride = false;
      expect(TvPanelLayout.panelAt(9, false), TvExplorePanel.channel);
      expect(TvPanelLayout.panelAt(-1, false), TvExplorePanel.country);
    });
  });
}
