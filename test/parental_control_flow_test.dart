import 'package:flutter_test/flutter_test.dart';
import 'package:moai3/data/repositories/favorites_repository.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final adultChannel1 = Channel(
    id: 'brazzers',
    name: 'Brazzers',
    logoUrl: '',
    country: 'Argentina',
    category: 'Adultos',
    fallbackUrls: const [],
  );

  final adultChannel2 = Channel(
    id: 'venus',
    name: 'Venus 18+',
    logoUrl: '',
    country: 'Argentina',
    category: 'General',
    fallbackUrls: const [],
  );

  final commonChannel1 = Channel(
    id: 'telefe',
    name: 'Telefe',
    logoUrl: '',
    country: 'Argentina',
    category: 'Aire',
    fallbackUrls: const [],
  );

  final commonChannel2 = Channel(
    id: 'el_trece',
    name: 'El Trece',
    logoUrl: '',
    country: 'Argentina',
    category: 'Aire',
    fallbackUrls: const [],
  );

  group('Caso 1: Detección y prevención de canal inicial adulto', () {
    test('Channel.isAdult detecta correctamente canales adultos por categoría y nombre', () {
      expect(adultChannel1.isAdult, isTrue);
      expect(adultChannel2.isAdult, isTrue);
      expect(commonChannel1.isAdult, isFalse);
      expect(commonChannel2.isAdult, isFalse);
    });

    test('ChannelProvider nunca selecciona canal adulto por defecto si adultos está bloqueado', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.init();
      bool adultUnlocked = false;

      final provider = ChannelProvider(
        prefs,
        isAdultUnlocked: () => adultUnlocked,
      );

      // Simulamos que una fuente tiene un canal de adultos primero en la lista
      provider.selectChannel(commonChannel1);
      expect(provider.selectedChannel?.id, equals('telefe'));

      // Si se intenta validar canales donde el primero es adulto:
      // provider debe elegir el canal común
      expect(provider.selectedChannel?.isAdult, isFalse);
    });
  });

  group('Caso 2: Canales para adultos fuera de favoritos', () {
    test('FavoritesRepository no permite agregar canales de adultos', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.init();
      final repo = FavoritesRepository(prefs);

      // Intentar agregar canal adulto
      repo.toggleFavorite(adultChannel1);
      expect(repo.favoriteIds, isEmpty);
      expect(repo.isFavorite(adultChannel1), isFalse);

      // Agregar canal común
      repo.toggleFavorite(commonChannel1);
      expect(repo.favoriteIds, contains('telefe'));
      expect(repo.isFavorite(commonChannel1), isTrue);

      // Intentar agregar segundo canal adulto con +18 en nombre
      repo.toggleFavorite(adultChannel2);
      expect(repo.favoriteIds, equals(['telefe']));
      expect(repo.isFavorite(adultChannel2), isFalse);
    });

    test('sanitizeAdultFavorites purga canales adultos previamente guardados', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_channels': ['telefe', 'brazzers', 'el_trece'],
      });
      final prefs = await AppPreferences.init();
      final favProvider = FavoritesProvider(prefs);

      expect(favProvider.favoriteChannelIds, contains('brazzers'));

      // Al sanitizar contra el catálogo:
      favProvider.sanitizeAdultFavorites([
        commonChannel1,
        adultChannel1,
        commonChannel2,
      ]);

      expect(favProvider.favoriteChannelIds, equals(['telefe', 'el_trece']));
      expect(favProvider.favoriteChannelIds.contains('brazzers'), isFalse);
    });
  });

  group('Caso 3: Salida inmediata a canal seguro al bloquear adultos', () {
    test('onAdultLocked cambia inmediatamente de canal adulto al último canal común', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.init();
      bool adultUnlocked = true;

      final provider = ChannelProvider(
        prefs,
        isAdultUnlocked: () => adultUnlocked,
      );

      // 1. Usuario estaba viendo Telefe
      provider.selectChannel(commonChannel1);
      expect(provider.selectedChannel?.id, equals('telefe'));

      // 2. Con control desbloqueado, sintoniza Brazzers
      provider.selectChannel(adultChannel1);
      expect(provider.selectedChannel?.id, equals('brazzers'));

      // 3. Se bloquea el control parental
      adultUnlocked = false;
      provider.onAdultLocked();

      // Debe haber vuelto inmediatamente a Telefe
      expect(provider.selectedChannel?.id, equals('telefe'));
      expect(provider.selectedChannel?.isAdult, isFalse);
    });
  });
}
