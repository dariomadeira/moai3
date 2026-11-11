part of '../movie_player_screen.dart';

/// Las teclas del reproductor y los menús de audio y subtítulos.
extension _MoviePlayerKeys on _MoviePlayerScreenState {
  /// Con un menú abierto: ↑/↓ recorren, OK elige, ← o atrás lo cierran.
  KeyEventResult _onMenuKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final last = _menuOptions.length - 1;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final step = key == LogicalKeyboardKey.arrowUp ? -1 : 1;
      _update(() => _menuIndex = (_menuIndex + step).clamp(0, last));
      _resetOsdTimer();
    } else if (event is KeyDownEvent) {
      if (TvKeyHandler.isActionKey(key)) {
        _applyMenuOption(_menuIndex);
      } else if (key == LogicalKeyboardKey.arrowLeft ||
          _MoviePlayerScreenState._isBackKey(key)) {
        _update(() => _openMenu = null);
        _resetOsdTimer();
      }
    }
    return KeyEventResult.handled;
  }

  /// En las píldoras: ←/→ recorren, OK abre, ↑ o atrás vuelven a la barra.
  KeyEventResult _onMenuBarKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    final menus = _menus;
    final at = menus.indexOf(_selectedMenu!);
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final step = key == LogicalKeyboardKey.arrowLeft ? -1 : 1;
      _update(() {
        _selectedMenu = menus[(at + step).clamp(0, menus.length - 1)];
      });
    } else if (TvKeyHandler.isActionKey(key)) {
      _openSelectedMenu();
    } else if (key == LogicalKeyboardKey.arrowUp ||
        _MoviePlayerScreenState._isBackKey(key)) {
      _update(() => _selectedMenu = null);
    }
    _resetOsdTimer();
    return KeyEventResult.handled;
  }

  /// Abre el menú de la píldora con el foco en lo que está en uso.
  void _openSelectedMenu() {
    _update(() {
      _openMenu = _selectedMenu;
      final current = _menuOptions.indexWhere((o) => o.current);
      _menuIndex = current < 0 ? 0 : current;
    });
  }

  /// Aplica la opción [index] del menú abierto. Audio y subtítulo valen para
  /// esta película (el ajuste general no cambia; el audio queda recordado) y
  /// se fijan al cargar el video: se recarga en el mismo punto. El tamaño se
  /// ve al instante y queda abierto para probar.
  void _applyMenuOption(int index) {
    final resumeAt = _startAt ?? _currentPosition;
    switch (_openMenu) {
      case MoviePlayerMenu.audio:
        final option = _audioOptions[index];
        final changed = option != _currentAudio;
        _update(() => _selectedMenu = _openMenu = null);
        if (changed) {
          _chosenAudio = option;
          _preferredAudio = option.code;
          _preferredAudioOccurrence = option.occurrence;
          if (widget.saveProgress) {
            unawaited(
              MovieAudioChoices.save(
                _audioChoiceKey,
                code: option.code,
                occurrence: option.occurrence,
              ),
            );
          }
          _reloadAt(resumeAt);
        } else {
          _resetOsdTimer();
        }
      case MoviePlayerMenu.subtitles:
        final next = index == 0 ? null : _subtitleOptions[index - 1];
        final changed = next?.url != _subtitle?.url;
        _update(() => _selectedMenu = _openMenu = null);
        if (changed) {
          _subtitle = next;
          _reloadAt(resumeAt);
        } else {
          _resetOsdTimer();
        }
      case MoviePlayerMenu.size:
        context.read<TvSettingsProvider?>()?.setMovieSubtitleSize(
          MovieSubtitleSize.values[index],
        );
        _resetOsdTimer();
      case null:
        break;
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // Atrás del control: no se atiende acá. Sin atender, al soltarla Android
    // manda el pop del sistema, que es el que vale ([_onSystemBack]).
    // Atenderla al apretar (y no al soltar) cerraba el reproductor y, con el
    // pop que llegaba al soltar, también el detalle.
    if (event.logicalKey == LogicalKeyboardKey.goBack) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent &&
        _MoviePlayerScreenState._isBackKey(event.logicalKey)) {
      _lastKeyBack = DateTime.now();
    }
    if (_recommendAnswer != null) return _onRecommendKey(event);
    if (_openMenu != null) return _onMenuKey(event);
    if (_selectedMenu != null) return _onMenuBarKey(event);
    final key = event.logicalKey;
    final isArrow =
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;

    // Las flechas mantenidas aceleran la búsqueda; el resto sólo al apretar.
    if (isArrow && (event is KeyDownEvent || event is KeyRepeatEvent)) {
      if (_hasError) return KeyEventResult.handled;
      _scrub(
        forward: key == LogicalKeyboardKey.arrowRight,
        repeat: event is KeyRepeatEvent,
      );
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (TvKeyHandler.isActionKey(key)) {
      if (_hasError) {
        _retry();
      } else if (_scrubTarget != null) {
        _commitScrub();
      } else {
        _togglePlayPause();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown &&
        !_hasError &&
        _scrubTarget == null &&
        _menus.isNotEmpty) {
      _update(() => _selectedMenu = _menus.first);
      _resetOsdTimer();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.contextMenu) {
      _resetOsdTimer();
      return KeyEventResult.handled;
    }
    if (_MoviePlayerScreenState._isBackKey(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// El "atrás" del sistema: hace lo que haría la tecla. Si una tecla de
  /// atrás de teclado (Esc) ya lo atendió recién, se ignora.
  void _onSystemBack() {
    final keyBack = _lastKeyBack;
    if (keyBack != null &&
        DateTime.now().difference(keyBack) <
            _MoviePlayerScreenState._keyBackWindow) {
      return;
    }
    if (_recommendAnswer != null) {
      _closeRecommendPrompt();
    } else if (_openMenu != null) {
      _update(() => _openMenu = null);
      _resetOsdTimer();
    } else if (_selectedMenu != null) {
      _update(() => _selectedMenu = null);
      _resetOsdTimer();
    } else {
      _handleBack();
    }
  }
}
