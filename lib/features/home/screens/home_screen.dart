import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/features/home/areas/home_calendar_area.dart';
import 'package:moai3/features/home/areas/home_settings_area.dart';
import 'package:moai3/features/home/areas/home_tv_area.dart';
import 'package:moai3/features/home/widgets/double_back_exit_scope.dart';
import 'package:moai3/features/home/widgets/navigation_rail_section.dart';
import 'package:moai3/focus/tv_intents.dart';
import 'package:moai3/focus/tv_shortcuts.dart';
import 'package:moai3/helpers/notification_helper.dart';
import 'package:moai3/layout/settings_panel_layout.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/services/plugin_host_service.dart';
import 'package:moai3/services/plugin_update_service.dart';
import 'package:moai3/services/update_service.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/plugin_update_dialog.dart';
import 'package:moai3/widgets/dialogs/update_dialog.dart';

/// Shell del home — foco como moaiSmart:
/// Shortcuts D-pad globales; → del rail llama [HomeTvAreaState.requestEntryFocus].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _sectionTv = 0;
  static const int _sectionCalendar = 1;
  static const int _sectionSettings = 2;

  final FocusScopeNode _railScopeNode =
      FocusScopeNode(debugLabel: 'rail_scope');
  final FocusNode _railFocusNode = FocusNode(debugLabel: 'home_rail');
  final GlobalKey<HomeTvAreaState> _tvAreaKey = GlobalKey<HomeTvAreaState>();
  final GlobalKey<DoubleBackExitScopeState> _doubleBackKey =
      GlobalKey<DoubleBackExitScopeState>();

  final FocusNode _calendarEventsFocus = FocusNode(debugLabel: 'calendar_events');
  final FocusNode _calendarSubscriptionsFocus =
      FocusNode(debugLabel: 'calendar_subscriptions');
  int _activeCalendarPanelIndex = 0;

  final FocusNode _settingsTvFocus = FocusNode(debugLabel: 'settings_tv');
  final FocusNode _settingsGeneralFocus =
      FocusNode(debugLabel: 'settings_general');
  final FocusNode _settingsAboutFocus = FocusNode(debugLabel: 'settings_about');

  int _selectedIndex = _sectionTv;
  int _activeSettingsPanelIndex = SettingsPanelLayout.configTvPanelIndex;
  StreamSubscription<List<CalendarEvent>>? _liveEventsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoUpdate();
      _listenToLiveEvents();
    });
  }

  void _listenToLiveEvents() {
    final calendar = context.read<CalendarProvider>();
    _liveEventsSub = calendar.onLiveEventsStarted.listen((events) {
      if (!mounted || events.isEmpty) return;
      final message = CalendarProvider.formatLiveEventsMessage(events);
      final icon = CalendarProvider.getLiveEventsIcon(events);
      NotificationHelper.show(
        message: message,
        icon: icon,
        duration: events.length > 1
            ? const Duration(seconds: 5)
            : const Duration(seconds: 4),
      );
    });
  }

  Future<void> _checkAutoUpdate() async {
    // Esperar 4 segundos tras arrancar para permitir que la interfaz y canales carguen fluidamente
    await Future.delayed(const Duration(seconds: 4));
    if (!mounted) return;

    // 1. PRIORIDAD 1: Actualización del APK general del sistema
    final appUpdate = await UpdateService.checkForUpdate();
    if (appUpdate != null && mounted) {
      // Se muestra el diálogo del APK y se aborta cualquier búsqueda de plugins.
      // Si el usuario actualiza, el proceso se reinicia/reinstala.
      UpdateDialog.show(context, appUpdate);
      return;
    }

    // 2. PRIORIDAD 2: Solo si el APK general ya está al día, comprobar plugins
    if (!mounted) return;
    try {
      final pluginHost = context.read<PluginHostController>();
      if (pluginHost.sources.isNotEmpty) {
        final pendingUpdates =
            await PluginUpdateService.checkForUpdates(pluginHost.sources);
        if (pendingUpdates.isNotEmpty && mounted) {
          PluginUpdateDialog.show(context, pendingUpdates);
        }
      }
    } catch (e) {
      debugPrint('[HomeScreen] Error comprobando plugins: $e');
    }
  }

  @override
  void dispose() {
    _liveEventsSub?.cancel();
    _railFocusNode.dispose();
    _railScopeNode.dispose();
    _calendarEventsFocus.dispose();
    _calendarSubscriptionsFocus.dispose();
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

  void _focusCalendarPanelByIndex(int index) {
    if (index == 0) {
      _requestFocusWithRetry(_calendarEventsFocus);
    } else {
      _requestFocusWithRetry(_calendarSubscriptionsFocus);
    }
  }

  void _onCalendarPanelIndexChanged(int index) {
    setState(() => _activeCalendarPanelIndex = index);
    _focusCalendarPanelByIndex(index);
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
    if (_selectedIndex == _sectionCalendar) {
      _focusCalendarPanelByIndex(_activeCalendarPanelIndex);
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
    if (_selectedIndex == _sectionCalendar) {
      if (_railFocusNode.hasFocus) {
        setState(() => _selectedIndex = _sectionTv);
        return true;
      }
      _focusRail();
      return true;
    }
    if (_selectedIndex == _sectionSettings) {
      if (_railFocusNode.hasFocus) {
        setState(() => _selectedIndex = _sectionTv);
        return true;
      }
      _focusRail();
      return true;
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
                          padding: _selectedIndex == _sectionTv
                              ? const EdgeInsets.fromLTRB(8, 0, 8, 8)
                              : const EdgeInsets.all(8),
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
                              : _selectedIndex == _sectionCalendar
                                  ? HomeCalendarArea(
                                      activePanelIndex:
                                          _activeCalendarPanelIndex,
                                      eventsPanelFocus: _calendarEventsFocus,
                                      subscriptionsPanelFocus:
                                          _calendarSubscriptionsFocus,
                                      onPanelIndexChanged:
                                          _onCalendarPanelIndexChanged,
                                      onExitLeft: _focusRail,
                                      onTuneChannel: (channel) {
                                        context.read<ChannelProvider>().selectChannel(channel);
                                        setState(() => _selectedIndex = _sectionTv);
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (mounted) {
                                            _tvAreaKey.currentState?.selectChannel(channel);
                                            _tvAreaKey.currentState?.requestViewerFocus();
                                          }
                                        });
                                      },
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

