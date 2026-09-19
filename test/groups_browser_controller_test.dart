import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/groups/controllers/groups_browser_controller.dart';
import 'package:moai3/models/channel_group.dart';

void main() {
  group('GroupsBrowserController', () {
    late GroupsBrowserController controller;

    final customGroup = ChannelGroup(
      id: 'custom_123',
      name: 'Mis Pelis',
      icon: 'movie',
      type: 'custom',
      channelIds: ['c1'],
    );

    final systemGroup = ChannelGroup(
      id: 'deportes',
      name: 'Deportes',
      icon: 'sports_soccer',
      type: 'category',
      channelIds: ['c2'],
    );

    setUp(() {
      controller = GroupsBrowserController();
      controller.syncFrom([customGroup, systemGroup], [], []);
    });

    tearDown(() {
      controller.dispose();
    });

    test(
        'activateAlphabetMode en grupo personalizado habilita canDeleteAlphabetGroup',
        () {
      expect(controller.isAlphabetMode, isFalse);

      final success = controller.activateAlphabetMode(customGroup);
      expect(success, isTrue);
      expect(controller.isAlphabetMode, isTrue);
      expect(controller.canDeleteAlphabetGroup, isTrue);
      expect(controller.alphabetLetters, contains('D'));
      expect(controller.alphabetLetters, contains('M'));
      expect(
        controller.alphabetFocusNodes.length,
        controller.alphabetLetters.length + 1,
      );
    });

    test(
        'activateAlphabetMode en grupo del sistema NO habilita canDeleteAlphabetGroup',
        () {
      final success = controller.activateAlphabetMode(systemGroup);
      expect(success, isTrue);
      expect(controller.isAlphabetMode, isTrue);
      expect(controller.canDeleteAlphabetGroup, isFalse);
      expect(
        controller.alphabetFocusNodes.length,
        controller.alphabetLetters.length,
      );
    });

    test('clearAlphabetMode resetea el estado alfabético', () {
      controller.activateAlphabetMode(customGroup);
      expect(controller.isAlphabetMode, isTrue);

      controller.clearAlphabetMode();
      expect(controller.isAlphabetMode, isFalse);
      expect(controller.alphabetModeGroup, isNull);
    });
  });
}

