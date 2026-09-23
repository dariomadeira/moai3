import 'package:flutter/foundation.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/app_preferences_service.dart';
import 'package:moai3/utils/safe_change_notifier.dart';

class FavoritesRepository extends ChangeNotifier with SafeChangeNotifier {
  static const String _favoriteChannelsKey = 'favorite_channels';

  final AppPreferences _prefs;
  final List<String> _favoriteIds = [];

  FavoritesRepository(this._prefs);

  List<String> get favoriteIds => List.unmodifiable(_favoriteIds);

  void loadFromPrefs() {
    final saved = _prefs.readStringList(_favoriteChannelsKey);
    _favoriteIds
      ..clear()
      ..addAll(saved);
  }

  bool isFavorite(Channel channel) {
    if (channel.isAdult) return false;
    return _favoriteIds.contains(channel.id);
  }

  void toggleFavorite(Channel channel) {
    // Los canales de adultos bajo control parental nunca pueden ser favoritos.
    if (channel.isAdult) return;

    if (_favoriteIds.contains(channel.id)) {
      _favoriteIds.remove(channel.id);
    } else {
      _favoriteIds.add(channel.id);
    }
    _persist();
    safeNotifyListeners();
  }

  /// Limpia cualquier canal de adultos que pudiera haber sido guardado previamente.
  void sanitizeAdultFavorites(List<Channel> channels) {
    final adultIds = channels.where((c) => c.isAdult).map((c) => c.id).toSet();
    final hadAdults = _favoriteIds.any(adultIds.contains);
    if (hadAdults) {
      _favoriteIds.removeWhere(adultIds.contains);
      _persist();
      safeNotifyListeners();
    }
  }

  void clearAllFavorites() {
    _favoriteIds.clear();
    _persist();
    safeNotifyListeners();
  }

  Future<void> _persist() async {
    await _prefs.saveStringList(_favoriteChannelsKey, _favoriteIds);
  }
}

