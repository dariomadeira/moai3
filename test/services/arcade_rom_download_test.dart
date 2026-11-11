import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/features/games/models/arcade_rom_item.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/platform/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory romDir;
  late HttpServer server;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() async {
    // El binding de tests responde 400 a todo: acá hace falta el servidor real.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    romDir = await Directory.systemTemp.createTemp('arcade_rom_test');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    messenger.setMockMethodCallHandler(PlatformChannels.arcade, (
      MethodCall call,
    ) async {
      switch (call.method) {
        case 'getRomDirectory':
          return romDir.path;
        case 'getInstalledRoms':
          return <Map<String, Object>>[];
      }
      return null;
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(PlatformChannels.arcade, null);
    await server.close(force: true);
    await romDir.delete(recursive: true);
  });

  ArcadeRomItem romFrom(String path) => ArcadeRomItem(
    id: 'rom',
    name: 'ROM',
    filename: 'rom.zip',
    url: 'http://${server.address.address}:${server.port}$path',
  );

  test('una descarga cortada no deja archivos a medias', () async {
    server.listen((request) async {
      request.response.contentLength = 1000;
      final socket = await request.response.detachSocket();
      socket.add(List.filled(10, 1));
      await socket.flush();
      socket.destroy();
    });

    final manager = ArcadeRomManagerService();
    final ok = await manager.downloadRom(romFrom('/cortada.zip'));

    expect(ok, isFalse);
    expect(manager.downloadProgress, isEmpty);
    expect(romDir.listSync(), isEmpty);
  });

  test('un error HTTP no deja archivos a medias', () async {
    server.listen((request) async {
      request.response.statusCode = 404;
      await request.response.close();
    });

    final manager = ArcadeRomManagerService();
    final ok = await manager.downloadRom(romFrom('/falta.zip'));

    expect(ok, isFalse);
    expect(romDir.listSync(), isEmpty);
  });

  test('una descarga completa queda con su nombre final', () async {
    server.listen((request) async {
      request.response.contentLength = 4;
      request.response.add([1, 2, 3, 4]);
      await request.response.close();
    });

    final manager = ArcadeRomManagerService();
    final ok = await manager.downloadRom(romFrom('/completa.zip'));

    expect(ok, isTrue);
    final names = romDir
        .listSync()
        .map((entry) => entry.uri.pathSegments.last)
        .toList();
    expect(names, ['rom.zip']);
  });
}
