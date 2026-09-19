import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/favorites/controllers/favorites_list_controller.dart';
import 'package:moai3/models/channel.dart';

Channel _channel(String id, String name) => Channel(
      id: id,
      name: name,
      logoUrl: 'assets/channels/america.jpg',
      fallbackUrls: const ['http://example.com/stream'],
    );

void main() {
  test('syncFrom repuebla favoritos cuando llegan los canales', () {
    final controller = FavoritesListController();

    controller.syncFrom([], ['1', '2']);
    expect(controller.favoriteChannels, isEmpty);

    controller.syncFrom(
      [_channel('1', 'TELEFE'), _channel('2', 'El Trece')],
      ['1', '2'],
    );
    expect(controller.favoriteChannels, hasLength(2));
    expect(controller.favoriteChannels.first.name, 'El Trece');
    expect(controller.favoriteChannels.last.name, 'TELEFE');
  });

  test('syncFrom ignora ids que no están en el catálogo', () {
    final controller = FavoritesListController();
    controller.syncFrom([_channel('1', 'A')], ['1', 'missing']);
    expect(controller.favoriteChannels, hasLength(1));
    expect(controller.favoriteChannels.single.id, '1');
  });
}

