import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/channel_browser/controllers/channel_browser_controller.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plugin flow and channel selection validation', () {
    late AppPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await AppPreferences.init();
    });

    final channelPluginA = Channel(
      id: 'plugin:srcA:ch1',
      name: 'Telefe',
      logoUrl: '',
      country: 'Argentina',
      category: 'General',
      fallbackUrls: const [],
      pluginId: 'srcA',
      pluginChannelId: 'ch1',
      pluginName: 'Fuente A',
    );

    final channelPluginB = Channel(
      id: 'plugin:srcB:ch2',
      name: 'El Trece',
      logoUrl: '',
      country: 'Argentina',
      category: 'General',
      fallbackUrls: const [],
      pluginId: 'srcB',
      pluginChannelId: 'ch2',
      pluginName: 'Fuente B',
    );

    test('ChannelProvider initial state with empty preferences is empty', () async {
      final provider = ChannelProvider(prefs);
      expect(provider.selectedChannel, isNull);
      expect(provider.allChannels, isEmpty);
    });

    test('ChannelBrowserController syncFromChannels handles plugin removal gracefully', () {
      final controller = ChannelBrowserController();
      controller.initializeFromChannels([channelPluginA, channelPluginB]);

      expect(controller.countries, contains('Argentina'));
      expect(controller.selectedCountry, equals('Argentina'));

      // Remove plugin B and A (0 channels left)
      controller.syncFromChannels([]);

      expect(controller.countries, isEmpty);
      expect(controller.selectedCountry, equals(''));
      expect(controller.categories, isEmpty);
      expect(controller.channels, isEmpty);
      expect(controller.selectedChannel, isNull);
    });

    test('ChannelBrowserController syncFromChannels revalidates selection when plugin A is removed', () {
      final controller = ChannelBrowserController();
      controller.initializeFromChannels([channelPluginA, channelPluginB], initial: channelPluginA);

      expect(controller.selectedChannel?.id, equals(channelPluginA.id));

      // Remove plugin A, keeping plugin B
      controller.syncFromChannels([channelPluginB]);

      expect(controller.channels, hasLength(1));
      expect(controller.selectedChannel?.id, equals(channelPluginB.id));
    });
  });
}
