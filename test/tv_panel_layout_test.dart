import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/config/app_config.dart';
import 'package:moai3/layout/tv_panel_layout.dart';

void main() {
  group('TvPanelLayout', () {
    tearDown(() {
      AppConfig.debugModeOverride = null;
    });

    test('sin debug: cuatro paneles, Buscar primero', () {
      AppConfig.debugModeOverride = false;
      const showTvLog = false;
      expect(TvPanelLayout.panelCount(showTvLog), 4);
      expect(TvPanelLayout.logPanelIndex(showTvLog), -1);
      expect(TvPanelLayout.searchPanelIndex(showTvLog), 0);
      expect(TvPanelLayout.countryPanelIndex(showTvLog), 1);
      expect(TvPanelLayout.categoryPanelIndex(showTvLog), 2);
      expect(TvPanelLayout.channelPanelIndex(showTvLog), 3);
      expect(TvPanelLayout.isSearchPanel(0, showTvLog), isTrue);
      expect(TvPanelLayout.isCountryPanel(1, showTvLog), isTrue);
      expect(TvPanelLayout.isCategoryPanel(2, showTvLog), isTrue);
      expect(TvPanelLayout.isChannelPanel(3, showTvLog), isTrue);
      expect(TvPanelLayout.isLogPanel(0, showTvLog), isFalse);
    });

    test('con debug y showTvLog: cinco paneles, TV log primero', () {
      AppConfig.debugModeOverride = true;
      const showTvLog = true;
      expect(TvPanelLayout.panelCount(showTvLog), 5);
      expect(TvPanelLayout.logPanelIndex(showTvLog), 0);
      expect(TvPanelLayout.searchPanelIndex(showTvLog), 1);
      expect(TvPanelLayout.countryPanelIndex(showTvLog), 2);
      expect(TvPanelLayout.categoryPanelIndex(showTvLog), 3);
      expect(TvPanelLayout.channelPanelIndex(showTvLog), 4);
      expect(TvPanelLayout.isLogPanel(0, showTvLog), isTrue);
      expect(TvPanelLayout.isSearchPanel(1, showTvLog), isTrue);
      expect(TvPanelLayout.isCountryPanel(2, showTvLog), isTrue);
      expect(TvPanelLayout.isCategoryPanel(3, showTvLog), isTrue);
      expect(TvPanelLayout.isChannelPanel(4, showTvLog), isTrue);
    });

    test('con debug pero showTvLog=false: cuatro paneles sin log', () {
      AppConfig.debugModeOverride = true;
      const showTvLog = false;
      expect(TvPanelLayout.panelCount(showTvLog), 4);
      expect(TvPanelLayout.isLogPanel(0, showTvLog), isFalse);
      expect(TvPanelLayout.searchPanelIndex(showTvLog), 0);
      expect(TvPanelLayout.channelPanelIndex(showTvLog), 3);
    });
  });
}

