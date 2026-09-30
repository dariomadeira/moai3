import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/layout/settings_panel_layout.dart';

void main() {
  group('SettingsPanelLayout', () {
    test('tiene cinco paneles: TV, Agenda, Miremos Juntos, Generales y Acerca de', () {
      expect(SettingsPanelLayout.panelCount, 5);
      expect(SettingsPanelLayout.configTvPanelIndex, 0);
      expect(SettingsPanelLayout.configAgendaPanelIndex, 1);
      expect(SettingsPanelLayout.watchPartyPanelIndex, 2);
      expect(SettingsPanelLayout.configGeneralPanelIndex, 3);
      expect(SettingsPanelLayout.aboutPanelIndex, 4);
      expect(SettingsPanelLayout.isConfigTvPanel(0), isTrue);
      expect(SettingsPanelLayout.isConfigAgendaPanel(1), isTrue);
      expect(SettingsPanelLayout.isWatchPartyPanel(2), isTrue);
      expect(SettingsPanelLayout.isConfigGeneralPanel(3), isTrue);
      expect(SettingsPanelLayout.isAboutPanel(4), isTrue);
      expect(SettingsPanelLayout.isConfigTvPanel(1), isFalse);
      expect(SettingsPanelLayout.isConfigAgendaPanel(0), isFalse);
      expect(SettingsPanelLayout.isWatchPartyPanel(0), isFalse);
      expect(SettingsPanelLayout.isConfigGeneralPanel(1), isFalse);
      expect(SettingsPanelLayout.isAboutPanel(0), isFalse);
    });
  });
}

