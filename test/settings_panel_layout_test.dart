import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/layout/settings_panel_layout.dart';

void main() {
  group('SettingsPanelLayout', () {
    test('siempre tiene tres paneles: TV, Generales y Acerca de', () {
      expect(SettingsPanelLayout.panelCount, 3);
      expect(SettingsPanelLayout.configTvPanelIndex, 0);
      expect(SettingsPanelLayout.configGeneralPanelIndex, 1);
      expect(SettingsPanelLayout.aboutPanelIndex, 2);
      expect(SettingsPanelLayout.isConfigTvPanel(0), isTrue);
      expect(SettingsPanelLayout.isConfigGeneralPanel(1), isTrue);
      expect(SettingsPanelLayout.isAboutPanel(2), isTrue);
      expect(SettingsPanelLayout.isConfigTvPanel(1), isFalse);
      expect(SettingsPanelLayout.isConfigGeneralPanel(0), isFalse);
      expect(SettingsPanelLayout.isAboutPanel(0), isFalse);
    });
  });
}

