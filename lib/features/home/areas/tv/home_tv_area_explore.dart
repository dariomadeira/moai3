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

  Widget _buildExploreExpanded(int index, String title, bool showTvLog) {
    if (TvPanelLayout.isLogPanel(index, showTvLog)) {
      return DebugLogPanel(
        focusNode: _logFocus,
        onKeyLeft: widget.onExitLeft,
        onKeyRight: () {
          _activatePanel(TvPanelLayout.countryPanelIndex(showTvLog));
          _focusSelectedCountry();
        },
      );
    }

    if (TvPanelLayout.isCountryPanel(index, showTvLog)) {
      return Actions(
        actions: {
          DpadLeftIntent: CallbackAction<DpadLeftIntent>(
            onInvoke: (_) {
              if (_exploreAlphabetActive) return null;
              if (TvPanelLayout.hasLogPanel(showTvLog)) {
                _activatePanel(TvPanelLayout.logPanelIndex(showTvLog));
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
              _activatePanel(TvPanelLayout.categoryPanelIndex(showTvLog));
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
          onLongPress: () =>
              _activateAlphabet(TvPanelLayout.countryPanelIndex(showTvLog)),
          onFocusUp: _focusCurrentTab,
          emptyMessage: _channelLoadErrorMessage(),
        ),
      );
    }

    if (TvPanelLayout.isCategoryPanel(index, showTvLog)) {
      return Actions(
        actions: {
          DpadLeftIntent: CallbackAction<DpadLeftIntent>(
            onInvoke: (_) {
              if (_exploreAlphabetActive) return null;
              _activatePanel(TvPanelLayout.countryPanelIndex(showTvLog));
              _focusSelectedCountry();
              return null;
            },
          ),
          DpadRightIntent: CallbackAction<DpadRightIntent>(
            onInvoke: (_) {
              if (_exploreAlphabetActive) return null;
              _activatePanel(TvPanelLayout.channelPanelIndex(showTvLog));
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
          onLongPress: () =>
              _activateAlphabet(TvPanelLayout.categoryPanelIndex(showTvLog)),
          onFocusUp: _focusCurrentTab,
        ),
      );
    }

    return Actions(
      actions: {
        DpadLeftIntent: CallbackAction<DpadLeftIntent>(
          onInvoke: (_) {
            if (_exploreAlphabetActive) return null;
            _activatePanel(TvPanelLayout.categoryPanelIndex(showTvLog));
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
        onLongPress: () =>
            _activateAlphabet(TvPanelLayout.channelPanelIndex(showTvLog)),
        onFocusUp: _focusCurrentTab,
      ),
    );
  }
}
