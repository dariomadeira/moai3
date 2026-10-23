part of '../home_tv_area.dart';

/// Pestaña Explorar: acordeón de países, categorías y canales.
extension _TvAreaExplore on HomeTvAreaState {
  List<String> _titles(bool showTvLog) {
    final base = [
      LocaleKeys.home_panel_countries.tr(),
      LocaleKeys.home_panel_categories.tr(),
      LocaleKeys.home_panel_channels.tr(),
    ];
    return TvPanelLayout.hasLogPanel(showTvLog)
        ? [LocaleKeys.home_panel_tv_log.tr(), ...base]
        : base;
  }

  List<IconData> _icons(bool showTvLog) {
    final base = [
      MoaiIcons.tvAccordionGrupos,
      MoaiIcons.tvAccordionCategorias,
      MoaiIcons.tvAccordionCanales,
    ];
    return TvPanelLayout.hasLogPanel(showTvLog)
        ? [MoaiIcons.bugReportOutlined, ...base]
        : base;
  }

  Widget _buildExploreExpanded(
    TvExplorePanel panel,
    String title,
    bool showTvLog,
  ) {
    if (panel == TvExplorePanel.log) {
      return DebugLogPanel(
        focusNode: _logFocus,
        onKeyLeft: widget.onExitLeft,
        onKeyRight: () {
          _activatePanel(TvExplorePanel.country);
          _focusSelectedCountry();
        },
      );
    }

    if (panel == TvExplorePanel.country) {
      return Actions(
        actions: {
          DpadLeftIntent: CallbackAction<DpadLeftIntent>(
            onInvoke: (_) {
              if (_exploreAlphabetActive) return null;
              if (TvPanelLayout.hasLogPanel(showTvLog)) {
                _activatePanel(TvExplorePanel.log);
                _requestFocusWithRetry(_logFocus);
              } else {
                widget.onExitLeft();
              }
              return null;
            },
          ),
          DpadRightIntent: CallbackAction<DpadRightIntent>(
            onInvoke: (_) {
              if (_exploreAlphabetActive) return null;
              _activatePanel(TvExplorePanel.category);
              _focusSelectedCategory();
              return null;
            },
          ),
        },
        child: CountryListPanel(
          key: _countryPanelKey,
          title: title,
          countries: _browser.countries,
          countryFlags: _browser.countryFlags,
          selectedCountry: _browser.selectedCountry,
          onSelect: _selectCountry,
          onLongPress: () => _activateAlphabet(TvExplorePanel.country),
          onFocusUp: _focusCurrentTab,
          emptyMessage: _channelLoadErrorMessage(),
        ),
      );
    }

    if (panel == TvExplorePanel.category) {
      return Actions(
        actions: {
          DpadLeftIntent: CallbackAction<DpadLeftIntent>(
            onInvoke: (_) {
              if (_exploreAlphabetActive) return null;
              _activatePanel(TvExplorePanel.country);
              _focusSelectedCountry();
              return null;
            },
          ),
          DpadRightIntent: CallbackAction<DpadRightIntent>(
            onInvoke: (_) {
              if (_exploreAlphabetActive) return null;
              _activatePanel(TvExplorePanel.channel);
              _focusSelectedChannel();
              return null;
            },
          ),
        },
        child: CategoryListPanel(
          key: _categoryPanelKey,
          title: title,
          selectedCountry: _browser.selectedCountry,
          categories: _browser.categories,
          selectedCategory: _browser.selectedCategory,
          onSelect: _selectCategory,
          onLongPress: () => _activateAlphabet(TvExplorePanel.category),
          onFocusUp: _focusCurrentTab,
        ),
      );
    }

    return Actions(
      actions: {
        DpadLeftIntent: CallbackAction<DpadLeftIntent>(
          onInvoke: (_) {
            if (_exploreAlphabetActive) return null;
            _activatePanel(TvExplorePanel.category);
            _focusSelectedCategory();
            return null;
          },
        ),
        DpadRightIntent: CallbackAction<DpadRightIntent>(
          onInvoke: (_) {
            if (_exploreAlphabetActive) return null;
            _viewerFocus.requestFocus();
            return null;
          },
        ),
      },
      child: ChannelListPanel(
        key: _channelPanelKey,
        selectedCountry: _browser.selectedCountry,
        selectedCategory: _browser.selectedCategory,
        channels: _browser.channels,
        selectedChannel: _browser.selectedChannel,
        onSelect: _selectChannel,
        onLongPress: () => _activateAlphabet(TvExplorePanel.channel),
        onFocusUp: _focusCurrentTab,
      ),
    );
  }
}
