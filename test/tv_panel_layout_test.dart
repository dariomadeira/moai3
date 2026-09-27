import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/config/app_config.dart';
import 'package:moai3/layout/tv_panel_layout.dart';

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
  });
}
