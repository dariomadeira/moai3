import 'package:flutter/material.dart';
import 'package:moai3/data/repositories/favorites_repository.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/app_preferences_service.dart';

/// Provider responsable exclusivamente de la gestión y persistencia de canales favoritos.
class FavoritesProvider extends ChangeNotifier {
  late final FavoritesRepository _favoritesRepository;

  FavoritesProvider(AppPreferences prefs) {
    _favoritesRepository = FavoritesRepository(prefs)..loadFromPrefs();
    _favoritesRepository.addListener(notifyListeners);
  }

  List<String> get favoriteChannelIds => _favoritesRepository.favoriteIds;

  bool isFavorite(Channel channel) =>
      _favoritesRepository.isFavorite(channel);

  void toggleFavorite(Channel channel) =>
      _favoritesRepository.toggleFavorite(channel);

  void sanitizeAdultFavorites(List<Channel> channels) =>
      _favoritesRepository.sanitizeAdultFavorites(channels);

  void clearAllFavorites() => _favoritesRepository.clearAllFavorites();

  @override
  void dispose() {
    _favoritesRepository.removeListener(notifyListeners);
    _favoritesRepository.dispose();
    super.dispose();
  }
}
