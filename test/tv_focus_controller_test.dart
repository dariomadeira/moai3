import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/config/app_config.dart';
import 'package:moai3/focus/tv_focus_controller.dart';
import 'package:moai3/layout/tv_panel_layout.dart';

void main() {
  group('TvFocusController', () {
    tearDown(() {
      AppConfig.debugModeOverride = null;
      AppConfig.tvModeOverride = null;
    });

    test('restoreAfterRailRight en pestaña TV enfoca panel activo (Canales)',
        () {
      AppConfig.debugModeOverride = false;
      const showTvLog = false;
      final controller = TvFocusController();
      String? focused;

      controller.restoreAfterRailRight(
        activePanelIndex: TvPanelLayout.channelPanelIndex(showTvLog),
        showTvLog: showTvLog,
        focusDebug: () => focused = 'debug',
        focusCountry: () => focused = 'country',
        focusCategory: () => focused = 'category',
        focusChannel: () => focused = 'channel',
        focusSearch: () => focused = 'search',
      );

      expect(focused, 'channel');
    });

    test('restoreAfterRailRight en TV con Buscar activo enfoca búsqueda', () {
      AppConfig.debugModeOverride = false;
      const showTvLog = false;
      final controller = TvFocusController();
      String? focused;

      controller.restoreAfterRailRight(
        activePanelIndex: TvPanelLayout.searchPanelIndex(showTvLog),
        showTvLog: showTvLog,
        focusDebug: () => focused = 'debug',
        focusCountry: () => focused = 'country',
        focusCategory: () => focused = 'category',
        focusChannel: () => focused = 'channel',
        focusSearch: () => focused = 'search',
      );

      expect(focused, 'search');
    });

    test('restoreAfterRailRight en TV con debug y log activo enfoca debug', () {
      AppConfig.debugModeOverride = true;
      const showTvLog = true;
      final controller = TvFocusController();
      String? focused;

      controller.restoreAfterRailRight(
        activePanelIndex: TvPanelLayout.logPanelIndex(showTvLog),
        showTvLog: showTvLog,
        focusDebug: () => focused = 'debug',
        focusCountry: () => focused = 'country',
        focusCategory: () => focused = 'category',
        focusChannel: () => focused = 'channel',
        focusSearch: () => focused = 'search',
      );

      expect(focused, 'debug');
    });
  });
}

