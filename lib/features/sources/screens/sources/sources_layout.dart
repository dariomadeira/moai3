part of '../sources_screen.dart';

/// Barra de URL y columnas de fuentes instaladas y sugeridas.
extension _SourcesLayout on _SourcesScreenState {
  Widget _buildInputBar(
    BuildContext context,
    ColorScheme scheme,
    PluginHostController controller,
  ) {
    final hasSources = controller.sources.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: TvTextField(
            controller: _urlController,
            focusNode: _urlFocus,
            label: LocaleKeys.sources_url_label.tr(),
            hint: LocaleKeys.sources_url_hint.tr(),
            doneLabel: LocaleKeys.common_install.tr(),
            leadingIcon: MoaiIcons.tvSourcesUrlInput,
            onSubmitted: _install,
            onFocusLeft: _backFocusNode.requestFocus,
            onFocusRight: _installFocus.requestFocus,
            onFocusUp: _backFocusNode.requestFocus,
            onFocusDown: hasSources
                ? () => _tileFocuses.first.requestFocus()
                : _emptyFocusNode.requestFocus,
          ),
        ),
        const SizedBox(width: 10),
        TvFocusButton(
          focusNode: _installFocus,
          label: LocaleKeys.common_install.tr(),
          icon: MoaiIcons.tvSourcesInstallAction,
          height: 60,
          radius: 30,
          variant: TvButtonVariant.tonal,
          onPressed: controller.loading
              ? null
              : () {
                  final text = _urlController.text.trim();
                  if (text.isEmpty || text == 'https://' || text == 'http://') {
                    TvTextField.open(
                      context,
                      title: LocaleKeys.sources_url_label.tr(),
                      initialValue: text.isEmpty ? 'https://' : text,
                      hint: LocaleKeys.sources_url_hint.tr(),
                      doneLabel: LocaleKeys.common_install.tr(),
                    ).then((val) {
                      if (val != null && val.trim().isNotEmpty) {
                        _urlController.text = val;
                        _install(val);
                      }
                    });
                  } else {
                    _install();
                  }
                },
          onLongPress: controller.loading
              ? null
              : () {
                  _urlController.text = _SourcesScreenState._arUrl;
                  _install(_SourcesScreenState._arUrl);
                },
          onArrowLeft: _urlFocus.requestFocus,
          onArrowRight: _focusPresetList,
          onArrowUp: _backFocusNode.requestFocus,
          onArrowDown: hasSources
              ? () => _tileFocuses.first.requestFocus()
              : _emptyFocusNode.requestFocus,
        ),
      ],
    );
  }

  Widget _buildTwoColumnLayout(
    BuildContext context,
    ColorScheme scheme,
    PluginHostController controller,
    List<PluginSource> sources,
    int totalSources,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  LocaleKeys.sources_installed_header.tr(),
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: controller.loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: scheme.primary,
                          strokeWidth: 3,
                        ),
                      )
                    : totalSources == 0
                    ? TvEmptyStateCard(
                        focusNode: _emptyFocusNode,
                        icon: MoaiIcons.extensionEmpty,
                        message: LocaleKeys.sources_empty.tr(),
                        onFocusLeft: _backFocusNode.requestFocus,
                        onFocusUp: _urlFocus.requestFocus,
                        onFocusRight: _focusPresetList,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          const windowSize = 4;
                          final availableH = constraints.maxHeight;
                          final itemExtent = (availableH / windowSize).floorToDouble();

                          return SizedBox(
                            height: availableH,
                            child: TvWindowedList<PluginSource>(
                              key: _installedListKey,
                              items: sources,
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
                                source,
                                focusNode,
                                local,
                                global,
                                onKeyUp,
                                onKeyDown,
                              ) {
                                final isFirst = global == 0;
                                final updateNode = _tileFocuses[global * 2];
                                final removeNode = _tileFocuses[global * 2 + 1];

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: _SourceTile(
                                    key: ValueKey(source.id),
                                    source: source,
                                    updateFocus: updateNode,
                                    removeFocus: removeNode,
                                    onUpdateKeyLeft: _backFocusNode.requestFocus,
                                    onUpdateKeyUp: onKeyUp,
                                    onUpdateKeyDown: onKeyDown,
                                    onRemoveKeyUp: () {
                                      if (isFirst) {
                                        _installFocus.requestFocus();
                                      } else {
                                        onKeyUp();
                                      }
                                    },
                                    onRemoveKeyDown: onKeyDown,
                                    onRemoveKeyRight: _focusPresetList,
                                    onUpdate: () =>
                                        controller.updateSource(source.sourceUrl),
                                    onRemove: () =>
                                        controller.removePlugin(source.id),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  LocaleKeys.sources_presets_header.tr(),
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
                    const windowSize = 4;
                    final availableH = constraints.maxHeight;
                    final itemExtent = (availableH / windowSize).floorToDouble();

                    return SizedBox(
                      height: availableH,
                      child: TvWindowedList<_PresetPlugin>(
                        key: _presetsListKey,
                        items: _SourcesScreenState._presetPlugins,
                        windowSize: windowSize,
                        itemExtent: itemExtent,
                        showScrollDots: true,
                        initialGlobalIndex: _selectedPresetIndex,
                        focusOnMount: false,
                        onFocusedGlobalIndex: (idx) {
                          _selectedPresetIndex = idx;
                        },
                        onFocusUpFromFirst: _installFocus.requestFocus,
                        itemBuilder: (
                          context,
                          preset,
                          focusNode,
                          local,
                          global,
                          onKeyUp,
                          onKeyDown,
                        ) {
                          final isInstalled = sources.any(
                            (s) => s.sourceUrl == preset.url,
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: TvTile(
                              focusNode: focusNode,
                              minHeight: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              label: preset.name,
                              description: preset.description,
                              icon: MoaiIcons.plugin,
                              onPressed: () => _install(preset.url),
                              onKeyLeft: () {
                                if (totalSources > 0) {
                                  final targetIndex = (_selectedInstalledIndex * 2 + 1)
                                      .clamp(0, _tileFocuses.length - 1);
                                  _tileFocuses[targetIndex].requestFocus();
                                } else {
                                  _emptyFocusNode.requestFocus();
                                }
                              },
                              onKeyUp: onKeyUp,
                              onKeyDown: onKeyDown,
                              trailingBuilder: (context, isFocused) =>
                                  TvInstallPill(
                                isInstalled: isInstalled,
                                isFocused: isFocused,
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
