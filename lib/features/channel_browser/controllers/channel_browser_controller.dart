import 'package:flutter/material.dart';
import 'package:moai3/focus/focus_scroll_sync.dart';
import 'package:moai3/focus/tv_panel_layout.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/utils/safe_change_notifier.dart';

class ChannelBrowserController extends ChangeNotifier with SafeChangeNotifier {
  String selectedCountry = 'Argentina';
  String selectedCategory = '';
  Channel? selectedChannel;

  List<String> countries = [];
  Map<String, String> countryFlags = {};
  List<String> categories = [];
  List<Channel> channels = [];

  /// Panel con el salto alfabético abierto, o `null`.
  TvExplorePanel? alphabetPanel;
  List<String> alphabetLetters = [];
  final List<FocusNode> alphabetFocusNodes = [];

  bool isAdultUnlocked = false;

  static bool isAdult(Channel c) => c.isAdult;

  List<Channel> filterChannels(List<Channel> allChannels) {
    if (isAdultUnlocked) return allChannels;
    return allChannels.where((c) => !isAdult(c)).toList();
  }

  void _updateCountriesAndFlags(List<Channel> filtered) {
    countries =
        filtered
            .map((c) => c.country.trim().isEmpty ? 'General' : c.country.trim())
            .toSet()
            .toList()
          ..sort();
    final flags = <String, String>{};
    for (final c in filtered) {
      final name = c.country.trim().isEmpty ? 'General' : c.country.trim();
      final flag = c.countryFlagUrl;
      if (!flags.containsKey(name) && flag != null && flag.isNotEmpty) {
        flags[name] = flag;
      }
    }
    countryFlags = flags;
  }

  void syncFromChannels(List<Channel> allChannels, {bool? isAdultUnlocked}) {
    if (isAdultUnlocked != null) this.isAdultUnlocked = isAdultUnlocked;
    final filtered = filterChannels(allChannels);
    _updateCountriesAndFlags(filtered);

    if (countries.isEmpty) {
      selectedCountry = '';
      categories = [];
      channels = [];
      selectedCategory = '';
      selectedChannel = null;
      safeNotifyListeners();
      return;
    }

    if (!countries.contains(selectedCountry)) {
      selectedCountry = countries.first;
    }

    _refreshCategories(filtered);

    if (!categories.contains(selectedCategory)) {
      selectedCategory = categories.isNotEmpty ? categories.first : '';
    }

    _refreshChannels(filtered);

    if (selectedChannel != null &&
        !channels.any((c) => c.id == selectedChannel!.id)) {
      selectedChannel = channels.isNotEmpty ? channels.first : null;
    }

    safeNotifyListeners();
  }

  void syncPlayingChannel(
    Channel channel,
    List<Channel> allChannels, {
    bool? isAdultUnlocked,
  }) {
    if (isAdultUnlocked != null) this.isAdultUnlocked = isAdultUnlocked;
    if (!this.isAdultUnlocked && isAdult(channel)) {
      selectedChannel = channel;
      safeNotifyListeners();
      return;
    }
    final filtered = filterChannels(allChannels);
    _updateCountriesAndFlags(filtered);
    selectedChannel = channel;
    selectedCountry = channel.country.trim().isEmpty
        ? 'General'
        : channel.country.trim();
    _refreshCategories(filtered);
    selectedCategory = channel.category.trim().isEmpty
        ? 'General'
        : channel.category.trim();
    _refreshChannels(filtered);
    safeNotifyListeners();
  }

  void initializeFromChannels(
    List<Channel> allChannels, {
    Channel? initial,
    bool? isAdultUnlocked,
  }) {
    if (isAdultUnlocked != null) this.isAdultUnlocked = isAdultUnlocked;
    if (initial != null) {
      syncPlayingChannel(
        initial,
        allChannels,
        isAdultUnlocked: this.isAdultUnlocked,
      );
      if (countries.isNotEmpty) return;
    }
    final filtered = filterChannels(allChannels);
    _updateCountriesAndFlags(filtered);
    if (countries.isNotEmpty) {
      selectedCountry = countries.first;
    }
    _refreshCategories(filtered);

    final localCategories =
        filtered
            .where(
              (c) =>
                  (c.country.trim().isEmpty ? 'General' : c.country.trim()) ==
                  selectedCountry,
            )
            .map(
              (c) => c.category.trim().isEmpty ? 'General' : c.category.trim(),
            )
            .toSet()
            .toList()
          ..sort();
    selectedCategory = localCategories.isNotEmpty ? localCategories.first : '';

    _refreshChannels(filtered);
    if (channels.isNotEmpty) {
      selectedChannel = channels.first;
    }
    safeNotifyListeners();
  }

  void selectCountry(String country, List<Channel> allChannels) {
    final filtered = filterChannels(allChannels);
    selectedCountry = country;
    _refreshCategories(filtered);

    final localCategories =
        filtered
            .where(
              (c) =>
                  (c.country.trim().isEmpty ? 'General' : c.country.trim()) ==
                  country,
            )
            .map(
              (c) => c.category.trim().isEmpty ? 'General' : c.category.trim(),
            )
            .toSet()
            .toList()
          ..sort();
    selectedCategory = localCategories.isNotEmpty ? localCategories.first : '';

    _refreshChannels(filtered);
    selectedChannel = channels.isNotEmpty ? channels.first : null;
    safeNotifyListeners();
  }

  void selectCategory(String category, List<Channel> allChannels) {
    final filtered = filterChannels(allChannels);
    selectedCategory = category;
    _refreshChannels(filtered);
    selectedChannel = channels.isNotEmpty ? channels.first : null;
    safeNotifyListeners();
  }

  void selectChannel(Channel channel) {
    selectedChannel = channel;
    safeNotifyListeners();
  }

  void _refreshCategories(List<Channel> allChannels) {
    categories =
        allChannels
            .where(
              (c) =>
                  (c.country.trim().isEmpty ? 'General' : c.country.trim()) ==
                  selectedCountry,
            )
            .map(
              (c) => c.category.trim().isEmpty ? 'General' : c.category.trim(),
            )
            .toSet()
            .toList()
          ..sort();
  }

  void _refreshChannels(List<Channel> allChannels) {
    channels =
        allChannels
            .where(
              (c) =>
                  (c.country.trim().isEmpty ? 'General' : c.country.trim()) ==
                      selectedCountry &&
                  (c.category.trim().isEmpty ? 'General' : c.category.trim()) ==
                      selectedCategory,
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
  }

  /// Nombres del panel que admite salto alfabético, o `null` (log).
  List<String>? _alphabetItems(TvExplorePanel panel) => switch (panel) {
    TvExplorePanel.country => countries,
    TvExplorePanel.category => categories,
    TvExplorePanel.channel => channels.map((c) => c.name).toList(),
    TvExplorePanel.log => null,
  };

  bool activateAlphabetMode(TvExplorePanel panel) {
    final items = _alphabetItems(panel);
    if (items == null) return false;

    alphabetLetters =
        items
            .map((c) => c.isNotEmpty ? c[0].toUpperCase() : '')
            .where((l) => l.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (alphabetLetters.length <= 1) return false;

    FocusScrollSync.syncFocusNodes(alphabetLetters.length, alphabetFocusNodes);
    alphabetPanel = panel;
    safeNotifyListeners();
    FocusScrollSync.requestFocusAtIndex(alphabetFocusNodes, 0);
    return true;
  }

  void clearAlphabetMode() {
    alphabetPanel = null;
    safeNotifyListeners();
  }

  /// Selecciona el primer elemento con [letter] y devuelve el panel saltado.
  TvExplorePanel? jumpToLetter(String letter) {
    final panel = alphabetPanel;
    alphabetPanel = null;
    safeNotifyListeners();

    final items = panel == null ? null : _alphabetItems(panel);
    if (items == null) return null;

    final targetIdx = items.indexWhere(
      (c) => c.isNotEmpty && c.toUpperCase().startsWith(letter.toUpperCase()),
    );

    if (targetIdx != -1) {
      switch (panel!) {
        case TvExplorePanel.country:
          selectedCountry = items[targetIdx];
        case TvExplorePanel.category:
          selectedCategory = items[targetIdx];
        case TvExplorePanel.channel:
          selectedChannel = channels[targetIdx];
        case TvExplorePanel.log:
          break;
      }
      safeNotifyListeners();
    }
    return panel;
  }

  @override
  void dispose() {
    for (final node in alphabetFocusNodes) {
      FocusScrollSync.disposeNode(node);
    }
    super.dispose();
  }
}
