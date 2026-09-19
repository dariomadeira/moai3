import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moai3/focus/focus_scroll_sync.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/utils/safe_change_notifier.dart';

class HomeSearchController extends ChangeNotifier with SafeChangeNotifier {
  static const int minQueryLength = 2;
  static const int maxResults = 100;

  final TextEditingController queryController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  final FocusNode clearFocusNode = FocusNode();

  List<Channel> results = [];
  bool resultsCapped = false;
  Timer? _debounce;

  /// Filtro alfabético sobre los resultados actuales.
  bool isAlphabetMode = false;
  List<String> alphabetLetters = [];
  final List<FocusNode> alphabetFocusNodes = [];

  void initialize() {
    results = [];
    resultsCapped = false;
    clearAlphabetMode();
    safeNotifyListeners();
  }

  void attachQueryListener(List<Channel> Function() getAllChannels) {
    queryController.addListener(() {
      safeNotifyListeners();
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        updateResults(getAllChannels(), queryController.text);
      });
    });
  }

  void updateResults(List<Channel> allChannels, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty || trimmed.length < minQueryLength) {
      results = [];
      resultsCapped = false;
    } else {
      final cleanQuery = trimmed.toLowerCase();
      final matched = allChannels
          .where((c) => c.name.toLowerCase().contains(cleanQuery))
          .toList();
      matched.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      resultsCapped = matched.length > maxResults;
      results = matched.take(maxResults).toList();
    }
    // Si cambia la query, cerrar alfabeto (la lista ya no coincide).
    if (isAlphabetMode) {
      isAlphabetMode = false;
      alphabetLetters = [];
    }
    safeNotifyListeners();
  }

  bool get showSearchPrompt {
    final trimmed = queryController.text.trim();
    return trimmed.isEmpty || trimmed.length < minQueryLength;
  }

  bool get hasQuery => queryController.text.isNotEmpty;

  bool activateAlphabetMode() {
    if (results.length <= 1) return false;

    alphabetLetters = results
        .map((c) => c.name.isNotEmpty ? c.name[0].toUpperCase() : '')
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (alphabetLetters.length <= 1) return false;

    FocusScrollSync.syncFocusNodes(alphabetLetters.length, alphabetFocusNodes);
    isAlphabetMode = true;
    safeNotifyListeners();
    FocusScrollSync.requestFocusAtIndex(alphabetFocusNodes, 0);
    return true;
  }

  void clearAlphabetMode() {
    if (!isAlphabetMode && alphabetLetters.isEmpty) return;
    isAlphabetMode = false;
    alphabetLetters = [];
    safeNotifyListeners();
  }

  /// Cierra alfabeto y devuelve el índice del primer resultado con esa letra.
  int? jumpToLetter(String letter) {
    isAlphabetMode = false;
    alphabetLetters = [];
    safeNotifyListeners();

    final targetIdx = results.indexWhere(
      (c) =>
          c.name.isNotEmpty &&
          c.name.toUpperCase().startsWith(letter.toUpperCase()),
    );
    return targetIdx >= 0 ? targetIdx : null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    queryController.dispose();
    searchFocusNode.dispose();
    clearFocusNode.dispose();
    for (final node in alphabetFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}

