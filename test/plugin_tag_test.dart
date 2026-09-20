import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/plugin_host_service.dart';
import 'package:moai3/widgets/cards/new_channel_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Plugin Tag & Badge tests', () {
    test('PluginSource.fromMap parses explicit tag', () {
      final source = PluginSource.fromMap({
        'id': 'custom_plug',
        'tag': 'uy',
        'nombre': 'Plugin Uruguay',
        'version': '1.0.0',
        'minContrato': 1,
        'maxContrato': 1,
        'sourceUrl': '',
        'canales': [],
      });

      expect(source.tag, equals('uy'));
    });

    test('PluginSource.fromMap falls back to suffix of moai_ id when tag is missing', () {
      final source = PluginSource.fromMap({
        'id': 'moai_ar',
        'nombre': 'Plugin Argentina',
        'version': '1.0.0',
        'minContrato': 1,
        'maxContrato': 1,
        'sourceUrl': '',
        'canales': [],
      });

      expect(source.tag, equals('ar'));
    });

    test('PluginChannelCatalog.channelsFrom passes pluginTag to Channel', () {
      final source = PluginSource.fromMap({
        'id': 'moai_ar',
        'tag': 'ar',
        'nombre': 'Plugin Argentina',
        'version': '1.0.0',
        'minContrato': 1,
        'maxContrato': 1,
        'sourceUrl': '',
        'canales': [
          {
            'id': 'telefe',
            'nombre': 'Telefe',
            'logo': '',
            'categoria': 'Aire',
            'pais': 'Argentina',
          }
        ],
      });

      final channels = PluginChannelCatalog.channelsFrom([source]);
      expect(channels, hasLength(1));
      expect(channels.first.pluginTag, equals('ar'));
      expect(channels.first.pluginId, equals('moai_ar'));
    });

    testWidgets('NewChannelCard renders plugin tag badge in uppercase when present', (tester) async {
      final channelWithTag = Channel(
        id: 'plugin:moai_ar:telefe',
        name: 'Telefe',
        logoUrl: '',
        fallbackUrls: const [],
        pluginId: 'moai_ar',
        pluginChannelId: 'telefe',
        pluginTag: 'ar',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 250,
              child: NewChannelCard(
                channel: channelWithTag,
                isSelected: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('AR'), findsOneWidget);
    });

    testWidgets('NewChannelCard does not render badge when pluginTag is null or empty', (tester) async {
      final channelWithoutTag = Channel(
        id: 'base:telefe',
        name: 'Telefe',
        logoUrl: '',
        fallbackUrls: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 250,
              child: NewChannelCard(
                channel: channelWithoutTag,
                isSelected: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('AR'), findsNothing);
    });
  });
}
