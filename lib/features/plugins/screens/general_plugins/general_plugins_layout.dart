part of '../general_plugins_screen.dart';

/// Columnas de plugins instalados y disponibles.
extension _GeneralPluginsLayout on _GeneralPluginsScreenState {
  Widget _buildTwoColumnLayout(
    BuildContext context,
    ColorScheme scheme,
    bool isInstalled,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna Izquierda: Plugins Instalados
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  LocaleKeys.plugins_installed_column_title.tr(),
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: !isInstalled
                    ? TvEmptyStateCard(
                        focusNode: _emptyFocusNode,
                        icon: MoaiIcons.extensionOffOutlined,
                        message: LocaleKeys.plugins_empty_installed_msg.tr(),
                        onFocusLeft: _backFocusNode.requestFocus,
                        onFocusUp: _backFocusNode.requestFocus,
                        onFocusRight: _focusAvailableList,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          const windowSize = 5;
                          final availableH = constraints.maxHeight;
                          final itemExtent =
                              (availableH / windowSize).floorToDouble();
                          final tileMinHeight =
                              (itemExtent - 6.0).clamp(0.0, double.infinity);

                          return SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: _InstalledPluginTile(
                                title: LocaleKeys.plugins_arcade_name.tr(),
                                subtitle: LocaleKeys.plugins_arcade_desc.tr(
                                  namedArgs: {'abi': ArcadePluginService.getDeviceAbi()},
                                ),
                                minHeight: tileMinHeight,
                                updateFocus: _installedUpdateFocus,
                                removeFocus: _installedRemoveFocus,
                                onUpdate: _installArcade,
                                onRemove: _uninstallArcade,
                                onUpdateKeyLeft: _backFocusNode.requestFocus,
                                onUpdateKeyUp: _backFocusNode.requestFocus,
                                onRemoveKeyUp: _backFocusNode.requestFocus,
                                onRemoveKeyRight: _focusAvailableList,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Columna Derecha: Plugins Disponibles (Windowed List con mock de 8)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  LocaleKeys.plugins_available_column_title.tr(),
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const windowSize = 5;
                    final availableH = constraints.maxHeight;
                    final itemExtent = (availableH / windowSize).floorToDouble();

                    return SizedBox(
                      height: availableH,
                      child: TvWindowedList<_GeneralPluginItem>(
                        key: _availableListKey,
                        items: _availablePlugins,
                        windowSize: windowSize,
                        itemExtent: itemExtent,
                        showScrollDots: true,
                        initialGlobalIndex: _selectedAvailableIndex,
                        focusOnMount: false,
                        onFocusedGlobalIndex: (idx) {
                          _selectedAvailableIndex = idx;
                        },
                        onFocusUpFromFirst: _backFocusNode.requestFocus,
                        itemBuilder: (
                          context,
                          item,
                          focusNode,
                          local,
                          global,
                          onKeyUp,
                          onKeyDown,
                        ) {
                          final isItemInstalled = item.isArcade && isInstalled;
                          final isItemDownloading =
                              item.isArcade && _arcadePlugin.isDownloading;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: TvTile(
                              focusNode: focusNode,
                              minHeight: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              label: item.name,
                              description: item.description,
                              icon: MoaiIcons.tvViewerPillPlugin,
                              onPressed: () {
                                if (item.isArcade) {
                                  if (!isItemInstalled && !isItemDownloading) {
                                    _installArcade();
                                  }
                                }
                              },
                              onKeyLeft: () {
                                if (isInstalled) {
                                  _installedRemoveFocus.requestFocus();
                                } else {
                                  _emptyFocusNode.requestFocus();
                                }
                              },
                              onKeyUp: onKeyUp,
                              onKeyDown: onKeyDown,
                              trailingBuilder: (context, isFocused) =>
                                  TvInstallPill(
                                isInstalled: isItemInstalled,
                                isFocused: isFocused,
                                downloadProgress: isItemDownloading
                                    ? _arcadePlugin.downloadProgress
                                    : null,
                                installLabel: LocaleKeys.common_install.tr(),
                                installedLabel: LocaleKeys.common_installed.tr(),
                                onPressed: () {
                                  if (item.isArcade) {
                                    if (!isItemInstalled && !isItemDownloading) {
                                      _installArcade();
                                    }
                                  }
                                },
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
