import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/areas/home_settings_area.dart';
import 'package:moai3/features/home/areas/home_tv_area.dart';
import 'package:moai3/features/home/widgets/double_back_exit_scope.dart';
import 'package:moai3/features/home/widgets/navigation_rail_section.dart';
import 'package:moai3/focus/tv_intents.dart';
import 'package:moai3/focus/tv_shortcuts.dart';
import 'package:moai3/layout/settings_panel_layout.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';

/// Shell del home — foco como moaiSmart:
/// Shortcuts D-pad globales; → del rail llama [HomeTvAreaState.requestEntryFocus].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _sectionTv = 0;
  static const int _sectionSettings = 1;

  final FocusScopeNode _railScopeNode =
      FocusScopeNode(debugLabel: 'rail_scope');
  final FocusNode _railFocusNode = FocusNode(debugLabel: 'home_rail');
  final GlobalKey<HomeTvAreaState> _tvAreaKey = GlobalKey<HomeTvAreaState>();
  final GlobalKey<DoubleBackExitScopeState> _doubleBackKey =
      GlobalKey<DoubleBackExitScopeState>();

  final FocusNode _settingsTvFocus = FocusNode(debugLabel: 'settings_tv');
  final FocusNode _settingsGeneralFocus =
      FocusNode(debugLabel: 'settings_general');
  final FocusNode _settingsAboutFocus = FocusNode(debugLabel: 'settings_about');

  int _selectedIndex = _sectionTv;
  int _activeSettingsPanelIndex = SettingsPanelLayout.configTvPanelIndex;

  @override
  void dispose() {
    _railFocusNode.dispose();
    _railScopeNode.dispose();
    _settingsTvFocus.dispose();
    _settingsGeneralFocus.dispose();
    _settingsAboutFocus.dispose();
    super.dispose();
  }

  void _requestFocusWithRetry(FocusNode node, [int attempts = 15]) {
    if (!mounted) return;
    if (node.context != null) {
      node.requestFocus();
      return;
    }
    if (attempts <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestFocusWithRetry(node, attempts - 1);
    });
  }

  void _focusRail() {
    if (mounted) _railFocusNode.requestFocus();
  }

  void _focusSettingsPanelByIndex(int index) {
    if (SettingsPanelLayout.isConfigTvPanel(index)) {
      _requestFocusWithRetry(_settingsTvFocus);
    } else if (SettingsPanelLayout.isConfigGeneralPanel(index)) {
      _requestFocusWithRetry(_settingsGeneralFocus);
    } else if (SettingsPanelLayout.isAboutPanel(index)) {
      _requestFocusWithRetry(_settingsAboutFocus);
    }
  }

  /// → del rail — idéntico a Smart `_returnFocusToSettingsPanel`.
  void _onRailFocusRight() {
    _railFocusNode.unfocus();
    if (_selectedIndex == _sectionSettings) {
      _focusSettingsPanelByIndex(_activeSettingsPanelIndex);
      return;
    }
    _tvAreaKey.currentState?.requestEntryFocus();
  }

  void _onSettingsPanelIndexChanged(int index) {
    setState(() => _activeSettingsPanelIndex = index);
    _focusSettingsPanelByIndex(index);
  }

  bool _interceptBack() {
    if (_selectedIndex == _sectionTv) {
      return _tvAreaKey.currentState?.handleBack() ?? false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final overlapX = context.select((TvSettingsProvider s) => s.overlapPaddingX);
    final overlapY = context.select((TvSettingsProvider s) => s.overlapPaddingY);
    final scheme = context.scheme;

    return DoubleBackExitScope(
      key: _doubleBackKey,
      onBackIntercept: _interceptBack,
      child: Shortcuts(
        shortcuts: TvShortcuts.dpad,
        child: Actions(
          actions: <Type, Action<Intent>>{
            DpadBackIntent: CallbackAction<DpadBackIntent>(
              onInvoke: (_) {
                _doubleBackKey.currentState?.handleBack();
                return null;
              },
            ),
          },
          child: Scaffold(
            backgroundColor: scheme.surfaceContainer,
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: overlapX,
                  vertical: overlapY,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RepaintBoundary(
                      child: NavigationRailSection(
                        selectedIndex: _selectedIndex,
                        railScopeNode: _railScopeNode,
                        railFocusNode: _railFocusNode,
                        onIndexChanged: (index) {
                          setState(() => _selectedIndex = index);
                        },
                        onFocusRight: _onRailFocusRight,
                      ),
                    ),
                    Expanded(
                      child: RepaintBoundary(
                        child: Padding(
                          padding: _selectedIndex == _sectionSettings
                              ? const EdgeInsets.all(8)
                              : const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: _selectedIndex == _sectionSettings
                              ? HomeSettingsArea(
                                  activePanelIndex: _activeSettingsPanelIndex,
                                  tvPanelFocus: _settingsTvFocus,
                                  generalPanelFocus: _settingsGeneralFocus,
                                  aboutPanelFocus: _settingsAboutFocus,
                                  onPanelIndexChanged:
                                      _onSettingsPanelIndexChanged,
                                  onExitLeft: _focusRail,
                                )
                              : HomeTvArea(
                                  key: _tvAreaKey,
                                  onExitLeft: _focusRail,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

