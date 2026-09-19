import 'package:flutter/material.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/utils/safe_change_notifier.dart';

/// Lista derivada de favoritos para la barra horizontal del visor.
class FavoritesListController extends ChangeNotifier with SafeChangeNotifier {
  List<Channel> favoriteChannels = [];

  void syncFrom(
    List<Channel> allChannels,
    List<String> favoriteIds,
  ) {
    favoriteChannels = allChannels
        .where((c) => favoriteIds.contains(c.id))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    safeNotifyListeners();
  }
}

