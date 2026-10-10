import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:moai3/features/calendar/widgets/calendar_events_panel.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/features/home/areas/home_arcade_area.dart';
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
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/modal_route_tracker.dart';
import 'package:moai3/services/plugin_host_service.dart';
import 'package:moai3/services/plugin_update_service.dart';
import 'package:moai3/services/supabase_presence_service.dart';
import 'package:moai3/services/update_service.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
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
  static const int _sectionArcade = 2;
  static const int _sectionSettings = 3;

  final FocusNode _arcadeSelectGameFocus =
      FocusNode(debugLabel: 'arcade_select_game');
  final FocusNode _arcadeGamepadFocus =
      FocusNode(debugLabel: 'arcade_config_gamepad');
  final FocusNode _arcadeStartFocus =
      FocusNode(debugLabel: 'arcade_start_game');
  final ArcadeRomManagerService _romManager = ArcadeRomManagerService();

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
  final FocusNode _settingsAgendaFocus =
      FocusNode(debugLabel: 'settings_agenda');
  final FocusNode _settingsWatchPartyFocus =
      FocusNode(debugLabel: 'settings_watch_party');
  final FocusNode _settingsGeneralFocus =
      FocusNode(debugLabel: 'settings_general');
  final FocusNode _settingsAboutFocus = FocusNode(debugLabel: 'settings_about');

  int _selectedIndex = _sectionTv;
  int _activeSettingsPanelIndex = SettingsPanelLayout.configTvPanelIndex;
  StreamSubscription<List<CalendarEvent>>? _liveEventsSub;
  final List<CalendarEvent> _liveSnackQueue = [];
  bool _liveSnackBusy = false;
  bool _openingLiveSnackDialog = false;
  CalendarEvent? _currentSnackEvent;
  Timer? _modalClosedCooldownTimer;
  Timer? _tvPresenceHeartbeatTimer;

  static const Duration _tvPresenceHeartbeatInterval = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    _romManager.initialize();
    ModalRouteTracker.instance.addListener(_onModalTrackerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoUpdate();
      _listenToLiveEvents();
      _updatePresenceForSection(_selectedIndex);
    });
  }

  void _updatePresenceForSection(int index) {
    final identity = context.read<DeviceIdentityService>();
    final presence = context.read<SupabasePresenceService>();
    final watchParty = context.read<WatchPartyProvider>();
    final deviceId = identity.getOrCreateDeviceId();

    _tvPresenceHeartbeatTimer?.cancel();
    _tvPresenceHeartbeatTimer = null;

    if (index == _sectionTv) {
      // Estado Online exclusivamente en la sección TV
      presence.updateOnlineStatus(deviceId: deviceId, online: true);
      final ch = context.read<ChannelProvider>().selectedChannel;
      if (ch != null) {
        watchParty.reportCurrentChannel(channelId: ch.id, channelName: ch.name);
      }
      _tvPresenceHeartbeatTimer = Timer.periodic(_tvPresenceHeartbeatInterval, (_) {
        if (!mounted || _selectedIndex != _sectionTv) return;
        presence.sendHeartbeat(deviceId: deviceId);
      });
    } else {
      // Offline y limpiar canal sintonizado en Agenda, Arcade o Ajustes
      presence.updateOnlineStatus(deviceId: deviceId, online: false);
      watchParty.reportCurrentChannel(channelId: null);
    }
  }

  void _switchSection(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    _updatePresenceForSection(index);
  }

  void _onModalTrackerChanged() {
    if (!mounted) return;
    if (ModalRouteTracker.instance.hasActiveModal) {
      _modalClosedCooldownTimer?.cancel();
      // Si se abre un modal mientras hay una notificación visible, ocultarla
      // inmediatamente para no competir en pantalla ni por el foco del control remoto.
      if (_currentSnackEvent != null) {
        NotificationHelper.hideCurrent();
        if (_currentSnackEvent!.status != CalendarEventStatus.finished &&
            !_liveSnackQueue.any((e) => e.id == _currentSnackEvent!.id)) {
          _liveSnackQueue.insert(0, _currentSnackEvent!);
        }
        _currentSnackEvent = null;
        _liveSnackBusy = false;
      }
    } else {
      // El modal se cerró: esperar un respiro (400ms) para que el foco de la pantalla
      // principal se asiente y la animación termine antes de mostrar la siguiente notificación.
      _modalClosedCooldownTimer?.cancel();
      _modalClosedCooldownTimer = Timer(const Duration(milliseconds: 400), () {
        if (!mounted || ModalRouteTracker.instance.hasActiveModal) return;
        _cleanExpiredSnackQueue();
        _pumpLiveSnack();
      });
    }
  }

  void _cleanExpiredSnackQueue() {
    // Descartar notificaciones atrasadas cuyos eventos ya hayan finalizado
    _liveSnackQueue.removeWhere((e) => e.status == CalendarEventStatus.finished);
  }

  void _listenToLiveEvents() {
    final calendar = context.read<CalendarProvider>();
    _liveEventsSub = calendar.onLiveEventsStarted.listen((events) {
      if (!mounted || events.isEmpty) return;
      for (final ev in events) {
        if (ev.status == CalendarEventStatus.finished) continue;
        if (!_liveSnackQueue.any((item) => item.id == ev.id) &&
            _currentSnackEvent?.id != ev.id) {
          _liveSnackQueue.add(ev);
        }
      }
      if (!ModalRouteTracker.instance.hasActiveModal) {
        _pumpLiveSnack();
      }
    });
  }

  void _pumpLiveSnack() {
    if (!mounted ||
        _liveSnackBusy ||
        ModalRouteTracker.instance.hasActiveModal ||
        _openingLiveSnackDialog) {
      return;
    }
    _cleanExpiredSnackQueue();
    if (_liveSnackQueue.isEmpty) return;

    _liveSnackBusy = true;
    final event = _liveSnackQueue.removeAt(0);
    _currentSnackEvent = event;
    final lead = context.read<CalendarProvider>().notifyLeadMinutes;
    final controller = NotificationHelper.show(
      message: CalendarProvider.formatLiveEventsMessage(
        [event],
        leadMinutes: lead,
      ),
      icon: CalendarProvider.getLiveEventsIcon([event]),
      hint: 'calendar_live_ok_hint'.tr(),
      onAction: () => _openLiveSnackEvent(event),
      duration: context.read<CalendarProvider>().liveSnackDuration,
    );
    if (controller == null) {
      _currentSnackEvent = null;
      _liveSnackBusy = false;
      return;
    }
    controller.closed.then((_) {
      if (!mounted) return;
      _currentSnackEvent = null;
      _liveSnackBusy = false;
      if (ModalRouteTracker.instance.hasActiveModal || _openingLiveSnackDialog) {
        return;
      }
      // Intervalo de 800ms entre notificaciones consecutivas para no saturar al usuario
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || ModalRouteTracker.instance.hasActiveModal) return;
        _cleanExpiredSnackQueue();
        _pumpLiveSnack();
      });
    });
  }

  Future<void> _openLiveSnackEvent(CalendarEvent event) async {
    if (!mounted) return;
    _openingLiveSnackDialog = true;
    NotificationHelper.hideCurrent();
    _currentSnackEvent = null;
    await showCalendarEventDetails(
      context,
      event,
      onTuneChannel: (channel) {
        context.read<ChannelProvider>().selectChannel(channel);
        _switchSection(_sectionTv);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _tvAreaKey.currentState?.selectChannel(channel);
          _tvAreaKey.currentState?.requestViewerFocus();
        });
      },
    );
    if (!mounted) return;
    _openingLiveSnackDialog = false;
    _liveSnackBusy = false;
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
    _tvPresenceHeartbeatTimer?.cancel();
    ModalRouteTracker.instance.removeListener(_onModalTrackerChanged);
    _modalClosedCooldownTimer?.cancel();
    _liveEventsSub?.cancel();
    _railFocusNode.dispose();
    _railScopeNode.dispose();
    _calendarEventsFocus.dispose();
    _calendarSubscriptionsFocus.dispose();
    _settingsTvFocus.dispose();
    _settingsAgendaFocus.dispose();
    _settingsWatchPartyFocus.dispose();
    _settingsGeneralFocus.dispose();
    _settingsAboutFocus.dispose();
    _arcadeSelectGameFocus.dispose();
    _arcadeGamepadFocus.dispose();
    _arcadeStartFocus.dispose();
    _romManager.dispose();
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
    } else if (SettingsPanelLayout.isConfigAgendaPanel(index)) {
      _requestFocusWithRetry(_settingsAgendaFocus);
    } else if (SettingsPanelLayout.isWatchPartyPanel(index)) {
      _requestFocusWithRetry(_settingsWatchPartyFocus);
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
    if (_selectedIndex == _sectionArcade) {
      _requestFocusWithRetry(_arcadeSelectGameFocus);
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
        _switchSection(_sectionTv);
        return true;
      }
      _focusRail();
      return true;
    }
    if (_selectedIndex == _sectionArcade) {
      if (_railFocusNode.hasFocus) {
        _switchSection(_sectionTv);
        return true;
      }
      _focusRail();
      return true;
    }
    if (_selectedIndex == _sectionSettings) {
      if (_railFocusNode.hasFocus) {
        _switchSection(_sectionTv);
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: scheme.brightness == Brightness.dark
                    ? [
                        Color.lerp(scheme.surfaceContainerHigh, scheme.primary, 0.08)!,
                        scheme.surfaceContainerLow,
                      ]
                    : [
                        scheme.surfaceContainerLowest,
                        scheme.surfaceContainerHigh,
                      ],
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
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
                          _switchSection(index);
                        },
                        onFocusRight: _onRailFocusRight,
                      ),
                    ),
                    Expanded(
                      child: RepaintBoundary(
                        child: Padding(
                          padding: _selectedIndex == _sectionTv
                              ? const EdgeInsets.fromLTRB(4, 0, 8, 8)
                              : const EdgeInsets.fromLTRB(4, 8, 8, 8),
                          child: _selectedIndex == _sectionSettings
                              ? HomeSettingsArea(
                                  activePanelIndex: _activeSettingsPanelIndex,
                                  tvPanelFocus: _settingsTvFocus,
                                  agendaPanelFocus: _settingsAgendaFocus,
                                  watchPartyPanelFocus:
                                      _settingsWatchPartyFocus,
                                  generalPanelFocus: _settingsGeneralFocus,
                                  aboutPanelFocus: _settingsAboutFocus,
                                  onPanelIndexChanged:
                                      _onSettingsPanelIndexChanged,
                                  onExitLeft: _focusRail,
                                )
                              : _selectedIndex == _sectionArcade
                                  ? HomeArcadeArea(
                                      selectGameFocus: _arcadeSelectGameFocus,
                                      gamepadFocus: _arcadeGamepadFocus,
                                      startFocus: _arcadeStartFocus,
                                      onExitLeft: _focusRail,
                                      romManager: _romManager,
                                      onStartGame: () {
                                        final path = _romManager.getActiveRomPath();
                                        if (path != null) {
                                          context.push('/arcade/game', extra: path);
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'arcade_no_game_installed_snack'.tr(),
                                              ),
                                            ),
                                          );
                                        }
                                      },
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
                                        _switchSection(_sectionTv);
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
    ),
  );
}
}

