import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/channel_browser/controllers/channel_browser_controller.dart';
import 'package:moai3/models/channel.dart';

Channel _ch({
  required String id,
  required String name,
  required String country,
  required String category,
}) =>
    Channel(
      id: id,
      name: name,
      logoUrl: '',
      fallbackUrls: ['http://$id.m3u8'],
      country: country,
      category: category,
    );

void main() {
  group('ChannelBrowserController', () {
    test('deriva países y selección en cascada', () {
      final browser = ChannelBrowserController();
      final channels = [
        _ch(
          id: '1',
          name: 'Canal A',
          country: 'Argentina',
          category: 'Deportes',
        ),
        _ch(
          id: '2',
          name: 'Canal B',
          country: 'Chile',
          category: 'Noticias',
        ),
      ];

      browser.initializeFromChannels(channels);
      expect(browser.countries, ['Argentina', 'Chile']);
      expect(browser.selectedCountry, 'Argentina');

      browser.selectCountry('Chile', channels);
      expect(browser.selectedCountry, 'Chile');
      expect(browser.categories, ['Noticias']);
      expect(browser.channels.length, 1);
      expect(browser.channels.first.name, 'Canal B');

      browser.dispose();
    });

    test('syncPlayingChannel actualiza país, categoría y canal', () {
      final browser = ChannelBrowserController();
      final channels = [
        _ch(
          id: '1',
          name: 'Canal A',
          country: 'Argentina',
          category: 'Deportes',
        ),
        _ch(
          id: '2',
          name: 'Canal B',
          country: 'Chile',
          category: 'Noticias',
        ),
        _ch(
          id: '3',
          name: 'Canal C',
          country: 'Chile',
          category: 'Noticias',
        ),
      ];

      browser.initializeFromChannels(channels);
      expect(browser.selectedCountry, 'Argentina');

      browser.syncPlayingChannel(channels[1], channels);
      expect(browser.selectedChannel?.id, '2');
      expect(browser.selectedCountry, 'Chile');
      expect(browser.selectedCategory, 'Noticias');
      expect(browser.channels.map((c) => c.id), ['2', '3']);

      browser.dispose();
    });

    test('filtra canales adultos por defecto y los muestra cuando isAdultUnlocked es true', () {
      final browser = ChannelBrowserController();
      final channels = [
        _ch(
          id: '1',
          name: 'Canal Familiar',
          country: 'Argentina',
          category: 'Aire',
        ),
        _ch(
          id: '2',
          name: 'Canal +18 Adulto',
          country: 'Argentina',
          category: 'Adultos',
        ),
      ];

      // Bloqueado por defecto
      browser.initializeFromChannels(channels, isAdultUnlocked: false);
      expect(browser.categories, ['Aire']);
      expect(browser.channels.map((c) => c.id), ['1']);

      // Desbloqueado para la sesión
      browser.syncFromChannels(channels, isAdultUnlocked: true);
      expect(browser.categories, contains('Adultos'));

      browser.selectCategory('Adultos', channels);
      expect(browser.channels.map((c) => c.id), ['2']);

      browser.dispose();
    });
  });
}

