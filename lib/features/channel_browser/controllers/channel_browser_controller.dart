import 'package:flutter/material.dart';
import 'package:moai3/focus/focus_scroll_sync.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/layout/tv_panel_layout.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/utils/safe_change_notifier.dart';

class ChannelBrowserController extends ChangeNotifier with SafeChangeNotifier {
  String selectedCountry = 'Argentina';
  String selectedCategory = '';
  Channel? selectedChannel;

  List<String> countries = [];
  List<String> categories = [];
  List<Channel> channels = [];

  final List<FocusNode> countryFocusNodes = [];
  final List<FocusNode> categoryFocusNodes = [];
  final List<FocusNode> channelFocusNodes = [];

  final ScrollController countryScrollController = ScrollController();
  final ScrollController categoryScrollController = ScrollController();
  final ScrollController channelScrollController = ScrollController();

  int? alphabetModePanelIndex;
  List<String> alphabetLetters = [];
  final List<FocusNode> alphabetFocusNodes = [];

  bool _isAdult(Channel c) {
    return c.country == 'Adultos' ||
        c.category == 'Adultos' ||
        c.name.toLowerCase().contains('18+') ||
        c.name.toLowerCase().contains('+18');
  }

  void syncFromChannels(List<Channel> allChannels) {
    final filtered = allChannels.where((c) => !_isAdult(c)).toList();
    countries = filtered.map((c) => c.country).toSet().toList()..sort();
    FocusScrollSync.syncFocusNodes(countries.length, countryFocusNodes);

    if (countries.isEmpty) {
      selectedCountry = '';
      categories = [];
      FocusScrollSync.syncFocusNodes(0, categoryFocusNodes);
      channels = [];
      FocusScrollSync.syncFocusNodes(0, channelFocusNodes);
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

  void syncPlayingChannel(Channel channel, List<Channel> allChannels) {
    if (_isAdult(channel)) {
      selectedChannel = channel;
      safeNotifyListeners();
      return;
    }
    final filtered = allChannels.where((c) => !_isAdult(c)).toList();
    countries = filtered.map((c) => c.country).toSet().toList()..sort();
    FocusScrollSync.syncFocusNodes(countries.length, countryFocusNodes);
    selectedChannel = channel;
    selectedCountry = channel.country;
    _refreshCategories(filtered);
    selectedCategory = channel.category;
    _refreshChannels(filtered);
    safeNotifyListeners();
  }

  void initializeFromChannels(List<Channel> allChannels, {Channel? initial}) {
    if (initial != null) {
      syncPlayingChannel(initial, allChannels);
      if (countries.isNotEmpty) return;
    }
    final filtered = allChannels.where((c) => !_isAdult(c)).toList();
    countries = filtered.map((c) => c.country).toSet().toList()..sort();
    FocusScrollSync.syncFocusNodes(countries.length, countryFocusNodes);
    if (countries.isNotEmpty) {
      selectedCountry = countries.first;
    }
    _refreshCategories(filtered);

    final localCategories = filtered
        .where((c) => c.country == selectedCountry)
        .map((c) => c.category)
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
    final filtered = allChannels.where((c) => !_isAdult(c)).toList();
    selectedCountry = country;
    _refreshCategories(filtered);

    final localCategories = filtered
        .where((c) => c.country == country)
        .map((c) => c.category)
        .toSet()
        .toList()
      ..sort();
    selectedCategory = localCategories.isNotEmpty ? localCategories.first : '';

    _refreshChannels(filtered);
    selectedChannel = channels.isNotEmpty ? channels.first : null;
    safeNotifyListeners();
  }

  void selectCategory(String category, List<Channel> allChannels) {
    final filtered = allChannels.where((c) => !_isAdult(c)).toList();
    selectedCategory = category;
    _refreshChannels(filtered);
    selectedChannel = channels.isNotEmpty ? channels.first : null;
    safeNotifyListeners();
  }

  void selectChannel(Channel channel) {
    selectedChannel = channel;
    safeNotifyListeners();
  }

  int categoryPanelIndexAfterCountrySelect(bool showTvLog) =>
      TvPanelLayout.categoryPanelIndex(showTvLog);

  int channelPanelIndexAfterCategorySelect(bool showTvLog) =>
      TvPanelLayout.channelPanelIndex(showTvLog);

  void _refreshCategories(List<Channel> allChannels) {
    categories = allChannels
        .where((c) => c.country == selectedCountry)
        .map((c) => c.category)
        .toSet()
        .toList()
      ..sort();
    FocusScrollSync.syncFocusNodes(categories.length, categoryFocusNodes);
  }

  void _refreshChannels(List<Channel> allChannels) {
    channels = allChannels
        .where(
          (c) =>
              c.country == selectedCountry && c.category == selectedCategory,
        )
        .toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    FocusScrollSync.syncFocusNodes(channels.length, channelFocusNodes);
  }

  bool activateAlphabetMode(int panelIndex, bool showTvLog) {
    List<String> items;
    if (TvPanelLayout.isCountryPanel(panelIndex, showTvLog)) {
      items = countries;
    } else if (TvPanelLayout.isCategoryPanel(panelIndex, showTvLog)) {
      items = categories;
    } else if (TvPanelLayout.isChannelPanel(panelIndex, showTvLog)) {
      items = channels.map((c) => c.name).toList();
    } else {
      return false;
    }

    alphabetLetters = items
        .map((c) => c.isNotEmpty ? c[0].toUpperCase() : '')
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (alphabetLetters.length <= 1) return false;

    FocusScrollSync.syncFocusNodes(alphabetLetters.length, alphabetFocusNodes);
    alphabetModePanelIndex = panelIndex;
    safeNotifyListeners();
    FocusScrollSync.requestFocusAtIndex(alphabetFocusNodes, 0);
    return true;
  }

  void clearAlphabetMode() {
    alphabetModePanelIndex = null;
    safeNotifyListeners();
  }

  int? jumpToLetter(String letter, bool showTvLog) {
    final panelIndex = alphabetModePanelIndex ?? 0;
    alphabetModePanelIndex = null;
    safeNotifyListeners();

    final List<String> items;
    if (TvPanelLayout.isCountryPanel(panelIndex, showTvLog)) {
      items = countries;
    } else if (TvPanelLayout.isCategoryPanel(panelIndex, showTvLog)) {
      items = categories;
    } else if (TvPanelLayout.isChannelPanel(panelIndex, showTvLog)) {
      items = channels.map((c) => c.name).toList();
    } else {
      return null;
    }

    final targetIdx = items.indexWhere(
      (c) => c.isNotEmpty && c.toUpperCase().startsWith(letter.toUpperCase()),
    );

    if (targetIdx != -1) {
      if (TvPanelLayout.isCountryPanel(panelIndex, showTvLog)) {
        selectedCountry = items[targetIdx];
        safeNotifyListeners();
      } else if (TvPanelLayout.isCategoryPanel(panelIndex, showTvLog)) {
        selectedCategory = items[targetIdx];
        safeNotifyListeners();
      } else if (TvPanelLayout.isChannelPanel(panelIndex, showTvLog)) {
        selectedChannel = channels[targetIdx];
        safeNotifyListeners();
      }
    }
    return panelIndex;
  }

  void focusSelectedCountry() {
    var idx = countries.indexOf(selectedCountry);
    if (idx == -1 && countries.isNotEmpty) idx = 0;
    if (idx == -1) return;
    FocusScrollSync.focusListItem(
      scrollController: countryScrollController,
      focusNodes: countryFocusNodes,
      index: idx,
      itemHeight: TvLayoutConstants.countryItemHeight,
      itemCount: countries.length,
    );
  }

  void focusSelectedCategory() {
    var idx = categories.indexOf(selectedCategory);
    if (idx == -1 && categories.isNotEmpty) idx = 0;
    if (idx == -1) return;
    FocusScrollSync.focusListItem(
      scrollController: categoryScrollController,
      focusNodes: categoryFocusNodes,
      index: idx,
      itemHeight: TvLayoutConstants.categoryItemHeight,
      itemCount: categories.length,
    );
  }

  void focusSelectedChannel() {
    if (selectedChannel == null && channels.isNotEmpty) {
      selectedChannel = channels.first;
    }
    var idx = channels.indexWhere((c) => c.id == selectedChannel?.id);
    if (idx == -1 && channels.isNotEmpty) idx = 0;
    if (idx == -1) return;
    FocusScrollSync.focusListItem(
      scrollController: channelScrollController,
      focusNodes: channelFocusNodes,
      index: idx,
      itemHeight: TvLayoutConstants.channelItemHeight,
      itemCount: channels.length,
    );
  }

  @override
  void dispose() {
    countryScrollController.dispose();
    categoryScrollController.dispose();
    channelScrollController.dispose();
    for (final node in countryFocusNodes) {
      node.dispose();
    }
    for (final node in categoryFocusNodes) {
      node.dispose();
    }
    for (final node in channelFocusNodes) {
      node.dispose();
    }
    for (final node in alphabetFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}

