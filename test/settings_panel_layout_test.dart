import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/layout/settings_panel_layout.dart';

void main() {
  group('SettingsPanelLayout', () {
    test('tiene cuatro paneles: TV, Agenda, Generales y Acerca de', () {
      expect(SettingsPanelLayout.panelCount, 4);
      expect(SettingsPanelLayout.configTvPanelIndex, 0);
      expect(SettingsPanelLayout.configAgendaPanelIndex, 1);
      expect(SettingsPanelLayout.configGeneralPanelIndex, 2);
      expect(SettingsPanelLayout.aboutPanelIndex, 3);
      expect(SettingsPanelLayout.isConfigTvPanel(0), isTrue);
      expect(SettingsPanelLayout.isConfigAgendaPanel(1), isTrue);
      expect(SettingsPanelLayout.isConfigGeneralPanel(2), isTrue);
      expect(SettingsPanelLayout.isAboutPanel(3), isTrue);
      expect(SettingsPanelLayout.isConfigTvPanel(1), isFalse);
      expect(SettingsPanelLayout.isConfigAgendaPanel(0), isFalse);
      expect(SettingsPanelLayout.isConfigGeneralPanel(1), isFalse);
      expect(SettingsPanelLayout.isAboutPanel(0), isFalse);
    });
  });
}

