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
      const showTvLog = false;
      expect(TvPanelLayout.panelCount(showTvLog), 3);
      expect(TvPanelLayout.logPanelIndex(showTvLog), -1);
      expect(TvPanelLayout.countryPanelIndex(showTvLog), 0);
      expect(TvPanelLayout.categoryPanelIndex(showTvLog), 1);
      expect(TvPanelLayout.channelPanelIndex(showTvLog), 2);
      expect(TvPanelLayout.isCountryPanel(0, showTvLog), isTrue);
      expect(TvPanelLayout.isCategoryPanel(1, showTvLog), isTrue);
      expect(TvPanelLayout.isChannelPanel(2, showTvLog), isTrue);
      expect(TvPanelLayout.isLogPanel(0, showTvLog), isFalse);
    });

    test('con debug y showTvLog: cuatro paneles, TV log primero', () {
      AppConfig.debugModeOverride = true;
      const showTvLog = true;
      expect(TvPanelLayout.panelCount(showTvLog), 4);
      expect(TvPanelLayout.logPanelIndex(showTvLog), 0);
      expect(TvPanelLayout.countryPanelIndex(showTvLog), 1);
      expect(TvPanelLayout.categoryPanelIndex(showTvLog), 2);
      expect(TvPanelLayout.channelPanelIndex(showTvLog), 3);
      expect(TvPanelLayout.isLogPanel(0, showTvLog), isTrue);
      expect(TvPanelLayout.isCountryPanel(1, showTvLog), isTrue);
      expect(TvPanelLayout.isCategoryPanel(2, showTvLog), isTrue);
      expect(TvPanelLayout.isChannelPanel(3, showTvLog), isTrue);
    });

    test('con debug pero showTvLog=false: tres paneles sin log', () {
      AppConfig.debugModeOverride = true;
      const showTvLog = false;
      expect(TvPanelLayout.panelCount(showTvLog), 3);
      expect(TvPanelLayout.isLogPanel(0, showTvLog), isFalse);
      expect(TvPanelLayout.countryPanelIndex(showTvLog), 0);
      expect(TvPanelLayout.channelPanelIndex(showTvLog), 2);
    });

    test('remapPanelIndex conserva panel lógico al togglear log', () {
      AppConfig.debugModeOverride = true;
      // Sin log → con log: países 0→1, categorías 1→2, canales 2→3
      expect(TvPanelLayout.remapPanelIndex(0, false, true), 1);
      expect(TvPanelLayout.remapPanelIndex(1, false, true), 2);
      expect(TvPanelLayout.remapPanelIndex(2, false, true), 3);
      // Con log → sin log: log 0→países 0; países 1→0; cat 2→1; ch 3→2
      expect(TvPanelLayout.remapPanelIndex(0, true, false), 0);
      expect(TvPanelLayout.remapPanelIndex(1, true, false), 0);
      expect(TvPanelLayout.remapPanelIndex(2, true, false), 1);
      expect(TvPanelLayout.remapPanelIndex(3, true, false), 2);
    });
  });
}
