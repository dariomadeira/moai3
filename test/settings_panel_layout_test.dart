import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/focus/settings_panel_layout.dart';

void main() {
  group('SettingsPanelLayout', () {
    test(
      'tiene seis paneles: TV, Películas/Series, Agenda, Miremos Juntos, Generales y Acerca de',
      () {
        expect(SettingsPanelLayout.panelCount, 6);
        expect(SettingsPanelLayout.configTvPanelIndex, 0);
        expect(SettingsPanelLayout.configMoviesSeriesPanelIndex, 1);
        expect(SettingsPanelLayout.configAgendaPanelIndex, 2);
        expect(SettingsPanelLayout.watchPartyPanelIndex, 3);
        expect(SettingsPanelLayout.configGeneralPanelIndex, 4);
        expect(SettingsPanelLayout.aboutPanelIndex, 5);
        expect(SettingsPanelLayout.isConfigTvPanel(0), isTrue);
        expect(SettingsPanelLayout.isConfigMoviesSeriesPanel(1), isTrue);
        expect(SettingsPanelLayout.isConfigAgendaPanel(2), isTrue);
        expect(SettingsPanelLayout.isWatchPartyPanel(3), isTrue);
        expect(SettingsPanelLayout.isConfigGeneralPanel(4), isTrue);
        expect(SettingsPanelLayout.isAboutPanel(5), isTrue);
        expect(SettingsPanelLayout.isConfigTvPanel(1), isFalse);
        expect(SettingsPanelLayout.isConfigMoviesSeriesPanel(0), isFalse);
        expect(SettingsPanelLayout.isConfigAgendaPanel(0), isFalse);
        expect(SettingsPanelLayout.isWatchPartyPanel(0), isFalse);
        expect(SettingsPanelLayout.isConfigGeneralPanel(1), isFalse);
        expect(SettingsPanelLayout.isAboutPanel(0), isFalse);
      },
    );
  });
}
