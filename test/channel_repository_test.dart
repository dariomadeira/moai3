import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/data/repositories/channel_repository.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Channel _channel(String id, String name) => Channel(
      id: id,
      name: name,
      logoUrl: '',
      fallbackUrls: const ['http://example.com/stream'],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await AppPreferences.init();
  });

  test('ChannelRepository crea, persiste y recarga grupos personalizados', () async {
    final repo = ChannelRepository(prefs);

    expect(repo.groups, isEmpty);

    await repo.createGroup('Deportes', ['c1', 'c2']);

    expect(repo.groups, hasLength(1));
    expect(repo.groups.first.name, 'Deportes');
    expect(repo.groups.first.type, 'custom');
    expect(repo.groups.first.channelIds, ['c1', 'c2']);

    // Crear un segundo repo con las mismas preferencias (simula reinicio de la app)
    final repo2 = ChannelRepository(prefs);
    expect(repo2.groups, hasLength(1));
    expect(repo2.groups.first.name, 'Deportes');
    expect(repo2.groups.first.channelIds, ['c1', 'c2']);
  });

  test('ChannelRepository filtra channelIds contra el catálogo activo en setPluginChannels', () async {
    final repo = ChannelRepository(prefs);
    await repo.createGroup('Favoritos Cine', ['c1', 'c2', 'c3']);

    // Solo existen c1 y c3 en el catálogo activo
    repo.setPluginChannels([
      _channel('c1', 'Cine 1'),
      _channel('c3', 'Cine 3'),
    ]);

    expect(repo.groups, hasLength(1));
    expect(repo.groups.first.channelIds, ['c1', 'c3']);
  });

  test('ChannelRepository elimina grupos correctamente y persiste el cambio', () async {
    final repo = ChannelRepository(prefs);
    await repo.createGroup('Para Borrar', ['c1']);
    expect(repo.groups, hasLength(1));

    final groupId = repo.groups.first.id;
    await repo.deleteGroup(groupId);

    expect(repo.groups, isEmpty);

    final repoReloaded = ChannelRepository(prefs);
    expect(repoReloaded.groups, isEmpty);
  });
}
