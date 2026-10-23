part of '../arcade_games_screen.dart';

/// Fila de URL y columnas de juegos instalados y catálogo.
extension _ArcadeGamesLayout on _ArcadeGamesScreenState {
  Widget _buildUrlRow(
    BuildContext context,
    ColorScheme scheme,
    bool hasInstalled,
  ) {
    return Row(
      children: [
        Expanded(
          child: TvTextField(
            controller: _urlController,
            focusNode: _urlFocus,
            label: LocaleKeys.arcade_input_url_label.tr(),
            hint: LocaleKeys.arcade_input_url_hint.tr(),
            doneLabel: LocaleKeys.arcade_input_url_done.tr(),
            leadingIcon: MoaiIcons.tvSourcesUrlInput,
            onSubmitted: (val) => _loadData(),
            onFocusLeft: _backFocusNode.requestFocus,
            onFocusRight: _refreshFocus.requestFocus,
            onFocusUp: _backFocusNode.requestFocus,
            onFocusDown: hasInstalled
                ? () => _installedDeleteFocuses.first.requestFocus()
                : _emptyFocusNode.requestFocus,
          ),
        ),
        const SizedBox(width: 10),
        TvFocusButton(
          focusNode: _refreshFocus,
          label: LocaleKeys.common_update.tr(),
          icon: MoaiIcons.arcadeCatalogRefresh,
          height: 60,
          radius: 30,
          variant: TvButtonVariant.tonal,
          onPressed: widget.romManager.isLoading ? null : _loadData,
          onArrowLeft: _urlFocus.requestFocus,
          onArrowRight: _focusCatalogList,
          onArrowUp: _backFocusNode.requestFocus,
          onArrowDown: hasInstalled
              ? () => _installedDeleteFocuses.first.requestFocus()
              : _emptyFocusNode.requestFocus,
        ),
      ],
    );
  }

  Widget _buildTwoColumnLayout(
    BuildContext context,
    ColorScheme scheme,
    List<ArcadeRomItem> installed,
    List<ArcadeRomItem> catalog,
    bool hasInstalled,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna 1: Juegos Instalados
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  LocaleKeys.arcade_installed_column_title.tr(),
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: !hasInstalled
                    ? TvEmptyStateCard(
                        focusNode: _emptyFocusNode,
                        icon: MoaiIcons.arcadeRomItem,
                        message: LocaleKeys.arcade_empty_installed_msg.tr(),
                        onFocusLeft: _backFocusNode.requestFocus,
                        onFocusUp: _urlFocus.requestFocus,
                        onFocusRight: _focusCatalogList,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          const windowSize = 4;
                          final availableH = constraints.maxHeight;
                          final itemExtent =
                              (availableH / windowSize).floorToDouble();

                          return SizedBox(
                            height: availableH,
                            child: TvWindowedList<ArcadeRomItem>(
                              key: _installedListKey,
                              items: installed,
                              windowSize: windowSize,
                              itemExtent: itemExtent,
                              showScrollDots: true,
                              initialGlobalIndex: _selectedInstalledIndex,
                              focusOnMount: false,
                              onFocusedGlobalIndex: (idx) {
                                _selectedInstalledIndex = idx;
                              },
                              onFocusUpFromFirst: _urlFocus.requestFocus,
                              itemBuilder: (
                                context,
                                item,
                                focusNode,
                                local,
                                global,
                                onKeyUp,
                                onKeyDown,
                              ) {
                                final isFirst = global == 0;
                                final deleteNode = _installedDeleteFocuses[global];

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: _InstalledRomTile(
                                    key: ValueKey(item.filename),
                                    item: item,
                                    deleteFocus: deleteNode,
                                    onDeleteKeyUp: () {
                                      if (isFirst) {
                                        _urlFocus.requestFocus();
                                      } else {
                                        onKeyUp();
                                      }
                                    },
                                    onDeleteKeyDown: onKeyDown,
                                    onDeleteKeyLeft: _backFocusNode.requestFocus,
                                    onDeleteKeyRight: _focusCatalogList,
                                    onDelete: () => _deleteRom(item),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Columna 2: Catálogo de Juegos Disponibles
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  LocaleKeys.arcade_available_column_title.tr(),
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: widget.romManager.isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: scheme.primary,
                          strokeWidth: 3,
                        ),
                      )
                    : catalog.isEmpty
                        ? Center(
                            child: Text(
                              widget.romManager.errorMessage?.tr() ??
                                  LocaleKeys.arcade_catalog_empty.tr(),
                              style:
                                  MoaiText.body(context, color: scheme.error),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              const windowSize = 4;
                              final availableH = constraints.maxHeight;
                              final itemExtent =
                                  (availableH / windowSize).floorToDouble();

                              return SizedBox(
                                height: availableH,
                                child: TvWindowedList<ArcadeRomItem>(
                                  key: _catalogListKey,
                                  items: catalog,
                                  windowSize: windowSize,
                                  itemExtent: itemExtent,
                                  showScrollDots: true,
                                  initialGlobalIndex: _selectedCatalogIndex,
                                  focusOnMount: false,
                                  onFocusedGlobalIndex: (idx) {
                                    _selectedCatalogIndex = idx;
                                  },
                                  onFocusUpFromFirst: _refreshFocus.requestFocus,
                                  itemBuilder: (
                                    context,
                                    item,
                                    focusNode,
                                    local,
                                    global,
                                    onKeyUp,
                                    onKeyDown,
                                  ) {
                                    final progress = widget.romManager
                                        .downloadProgress[item.filename];
                                    final isDownloading = progress != null;

                                    return Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 3),
                                      child: TvTile(
                                        focusNode: focusNode,
                                        minHeight: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        label: item.name,
                                        description:
                                            '${item.system} · ${item.year} · ${item.sizeLabel}',
                                        icon: MoaiIcons.arcadeRomItem,
                                        onPressed:
                                            item.isInstalled || isDownloading
                                                ? null
                                                : () => widget.romManager
                                                    .downloadRom(item),
                                        onKeyLeft: () {
                                          if (hasInstalled) {
                                            final targetIndex =
                                                _selectedInstalledIndex.clamp(
                                              0,
                                              _installedDeleteFocuses.length - 1,
                                            );
                                            _installedDeleteFocuses[targetIndex]
                                                .requestFocus();
                                          } else {
                                            _emptyFocusNode.requestFocus();
                                          }
                                        },
                                        onKeyUp: onKeyUp,
                                        onKeyDown: onKeyDown,
                                        trailingBuilder: (context, isFocused) =>
                                            TvInstallPill(
                                          isInstalled: item.isInstalled,
                                          isFocused: isFocused,
                                          downloadProgress: progress,
                                          installLabel: LocaleKeys.common_install.tr(),
                                          installedLabel:
                                              LocaleKeys.common_installed.tr(),
                                          onPressed:
                                              item.isInstalled || isDownloading
                                                  ? null
                                                  : () => widget.romManager
                                                      .downloadRom(item),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
