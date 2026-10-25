import 'dart:async';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:moai3/features/games/arcade_launcher.dart';
import 'package:moai3/features/calendar/widgets/calendar_event_details_dialog.dart';
import 'package:moai3/features/games/services/arcade_netplay_service.dart';
import 'package:moai3/features/games/services/arcade_rom_manager_service.dart';
import 'package:moai3/features/home/areas/home_area.dart';
import 'package:moai3/features/home/areas/home_arcade_area.dart';
import 'package:moai3/features/home/areas/home_calendar_area.dart';
import 'package:moai3/features/home/areas/home_dashboard_area.dart';
import 'package:moai3/features/home/areas/home_movies_area.dart';
import 'package:moai3/features/home/areas/home_settings_area.dart';
import 'package:moai3/features/home/areas/home_tv_area.dart';
import 'package:moai3/features/home/controllers/tv_browser_session.dart';
import 'package:moai3/features/home/coordinators/presence_coordinator.dart';
import 'package:moai3/features/home/coordinators/startup_update_checker.dart';
import 'package:moai3/features/home/home_section.dart';
import 'package:moai3/features/home/widgets/double_back_exit_scope.dart';
import 'package:moai3/features/home/widgets/tv_vertical_nav_rail.dart';
import 'package:moai3/focus/tv_intents.dart';
import 'package:moai3/focus/tv_shortcuts.dart';
import 'package:moai3/widgets/feedback/notification_helper.dart';
import 'package:moai3/focus/settings_panel_layout.dart';
import 'package:moai3/models/calendar_event.dart';
import 'package:moai3/services/arcade_plugin_service.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/modal_route_tracker.dart';
import 'package:moai3/services/supabase_presence_service.dart';
import 'package:moai3/state/calendar_provider.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/featured_movies_provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_ambient_background.dart';

/// Shell del home — foco como moaiSmart:
/// Shortcuts D-pad globales; → del rail llama [HomeTvAreaState.requestEntryFocus].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ArcadeRomManagerService _romManager = ArcadeRomManagerService();
  StreamSubscription? _arcadeInviteSubscription;

  final FocusScopeNode _railScopeNode = FocusScopeNode(
    debugLabel: 'rail_scope',
  );
  final FocusNode _railFocusNode = FocusNode(debugLabel: 'home_rail');
  final GlobalKey<HomeTvAreaState> _tvAreaKey = GlobalKey<HomeTvAreaState>();

  /// Una clave por sección: Destacados, Películas y Series comparten widget y
  /// necesitan claves distintas para no reutilizar el estado entre sí.
  late final Map<HomeSection, GlobalKey<HomeAreaState>> _areaKeys = {
    for (final section in HomeSection.values)
      section: section == HomeSection.tv
          ? _tvAreaKey
          : GlobalKey<HomeAreaState>(),
  };
  final GlobalKey<DoubleBackExitScopeState> _doubleBackKey =
      GlobalKey<DoubleBackExitScopeState>();

  /// Panel abierto de Agenda y Ajustes, para reabrirlo al volver.
  int _calendarPanelIndex = 0;
  int _settingsPanelIndex = SettingsPanelLayout.configTvPanelIndex;

  HomeSection _section = HomeSection.tv;
  StreamSubscription<List<CalendarEvent>>? _liveEventsSub;
  final List<CalendarEvent> _liveSnackQueue = [];
  bool _liveSnackBusy = false;
  bool _openingLiveSnackDialog = false;
  CalendarEvent? _currentSnackEvent;
  Timer? _modalClosedCooldownTimer;
  late final PresenceCoordinator _presence;

  /// Navegación de TV que se conserva al ir a otras secciones y volver.
  final _tvSession = TvBrowserSession();

  @override
  void initState() {
    super.initState();
    _romManager.initialize();
    _presence = PresenceCoordinator(
      deviceId: context.read<DeviceIdentityService>().getOrCreateDeviceId(),
      presence: context.read<SupabasePresenceService>(),
      channels: context.read<ChannelProvider>(),
      watchParty: context.read<WatchPartyProvider>(),
      onBlocked: (reason) {
        if (mounted) context.go('/blocked', extra: reason);
      },
    );
    ModalRouteTracker.instance.addListener(_onModalTrackerChanged);
    ArcadePluginService.instance.addListener(_onArcadePluginChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(StartupUpdateChecker.run(context));
      _listenToLiveEvents();
      _updatePresenceForSection(_section);
      _listenToArcadeInvites();
    });
  }

  void _onArcadePluginChanged() {
    if (!mounted) return;
    if (_section == HomeSection.arcade &&
        !ArcadePluginService.instance.isInstalled) {
      _switchSection(HomeSection.tv);
    }
  }

  void _listenToArcadeInvites() {
    _arcadeInviteSubscription = ArcadeNetplayService.instance.onIncomingInvite
        .listen((invite) {
          if (!mounted) return;
          MoaiSnackBar.show(
            context,
            message: LocaleKeys.arcade_invite_received.tr(
              namedArgs: {'name': invite.hostNickname, 'game': invite.romName},
            ),
            icon: MoaiIcons.gamepadFilled,
            hint: LocaleKeys.arcade_invite_hint_accept_reject.tr(),
            onAction: () async {
              final identity = context.read<DeviceIdentityService>();
              final myDeviceId = identity.getOrCreateDeviceId();
              final myNickname =
                  context.read<WatchPartyProvider?>()?.myNickname ??
                  LocaleKeys.arcade_default_player_2.tr();

              await ArcadeNetplayService.instance.acceptIncomingInvite(
                myDeviceId: myDeviceId,
                myNickname: myNickname,
                romManager: _romManager,
              );

              if (mounted) {
                unawaited(ArcadeLauncher.prepareAndPlay(context, _romManager));
              }
            },
            onDismiss: () async {
              final identity = context.read<DeviceIdentityService>();
              final myDeviceId = identity.getOrCreateDeviceId();
              await ArcadeNetplayService.instance.rejectIncomingInvite(
                myDeviceId,
              );
            },
            duration: const Duration(seconds: 25),
          );
        });
  }

  void _updatePresenceForSection(HomeSection index) {
    _presence.setMode(switch (index) {
      HomeSection.tv => PresenceMode.watching,
      HomeSection.arcade => PresenceMode.available,
      _ => PresenceMode.offline,
    });
  }

  void _switchSection(HomeSection index) {
    if (_section == index) return;
    setState(() => _section = index);
    _updatePresenceForSection(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _railFocusNode.requestFocus();
      }
    });
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
    _liveSnackQueue.removeWhere(
      (e) => e.status == CalendarEventStatus.finished,
    );
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
      message: CalendarProvider.formatLiveEventsMessage([
        event,
      ], leadMinutes: lead),
      icon: CalendarProvider.getLiveEventsIcon([event]),
      hint: LocaleKeys.calendar_live_ok_hint.tr(),
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
      if (ModalRouteTracker.instance.hasActiveModal ||
          _openingLiveSnackDialog) {
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
        _switchSection(HomeSection.tv);
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

  @override
  void dispose() {
    _presence.dispose();
    _tvSession.dispose();
    ModalRouteTracker.instance.removeListener(_onModalTrackerChanged);
    _modalClosedCooldownTimer?.cancel();
    _liveEventsSub?.cancel();
    _railFocusNode.dispose();
    _railScopeNode.dispose();
    ArcadePluginService.instance.removeListener(_onArcadePluginChanged);
    _arcadeInviteSubscription?.cancel();
    _romManager.dispose();
    super.dispose();
  }

  void _focusRail() {
    if (mounted) _railFocusNode.requestFocus();
  }

  HomeAreaState? get _area => _areaKeys[_section]?.currentState;

  /// → del rail: el área activa decide dónde entra el foco.
  void _onRailFocusRight() {
    _railFocusNode.unfocus();
    _area?.requestEntryFocus();
  }

  bool _interceptBack() {
    if (_area?.handleBack() ?? false) return true;
    // En TV el back sin consumir lo maneja el doble back para salir.
    if (_section == HomeSection.tv) return false;
    // Fuera de TV: back desde el rail vuelve a TV; desde el contenido, al rail.
    if (_railFocusNode.hasFocus) {
      _switchSection(HomeSection.tv);
    } else {
      _focusRail();
    }
    return true;
  }

  Widget _buildArea() {
    return switch (_section) {
      HomeSection.home => HomeDashboardArea(
        key: _areaKeys[HomeSection.home],
        onExitLeft: _focusRail,
      ),
      HomeSection.settings => HomeSettingsArea(
        key: _areaKeys[HomeSection.settings],
        initialPanelIndex: _settingsPanelIndex,
        onPanelIndexChanged: (i) => _settingsPanelIndex = i,
        onExitLeft: _focusRail,
      ),
      HomeSection.arcade => HomeArcadeArea(
        key: _areaKeys[HomeSection.arcade],
        onExitLeft: _focusRail,
        romManager: _romManager,
      ),
      HomeSection.calendar => HomeCalendarArea(
        key: _areaKeys[HomeSection.calendar],
        initialPanelIndex: _calendarPanelIndex,
        onPanelIndexChanged: (i) => _calendarPanelIndex = i,
        onExitLeft: _focusRail,
        onTuneChannel: (channel) {
          context.read<ChannelProvider>().selectChannel(channel);
          _switchSection(HomeSection.tv);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _tvAreaKey.currentState?.selectChannel(channel);
              _tvAreaKey.currentState?.requestViewerFocus();
            }
          });
        },
      ),
      HomeSection.featured => HomeMoviesArea(
        key: _areaKeys[HomeSection.featured],
        panelTitle: LocaleKeys.movies_panel_featured_title.tr(),
        accordionIcon: MoaiIcons.tvAccordionFeatured,
        emptyMessage: LocaleKeys.movies_empty_featured.tr(),
        onExitLeft: _focusRail,
      ),
      HomeSection.movies => HomeMoviesArea(
        key: _areaKeys[HomeSection.movies],
        section: FeaturedMoviesProvider.sectionMovies,
        panelTitle: LocaleKeys.movies_panel_movies_title.tr(),
        accordionIcon: MoaiIcons.tvAccordionMovies,
        emptyMessage: LocaleKeys.movies_empty_movies.tr(),
        onExitLeft: _focusRail,
      ),
      HomeSection.series => HomeMoviesArea(
        key: _areaKeys[HomeSection.series],
        section: FeaturedMoviesProvider.sectionSeries,
        panelTitle: LocaleKeys.movies_panel_series_title.tr(),
        accordionIcon: MoaiIcons.tvAccordionSeries,
        emptyMessage: LocaleKeys.movies_empty_series.tr(),
        onExitLeft: _focusRail,
      ),
      HomeSection.tv => HomeTvArea(
        key: _tvAreaKey,
        onExitLeft: _focusRail,
        session: _tvSession,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final overlapX = context.select(
      (TvSettingsProvider s) => s.overlapPaddingX,
    );
    final overlapY = context.select(
      (TvSettingsProvider s) => s.overlapPaddingY,
    );

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
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(
                child: IgnorePointer(child: MoaiAmbientBackground()),
              ),
              Scaffold(
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
                          child: TvVerticalNavRail(
                            selected: _section,
                            railScopeNode: _railScopeNode,
                            railFocusNode: _railFocusNode,
                            onSelected: _switchSection,
                            onFocusRight: _onRailFocusRight,
                          ),
                        ),
                        Expanded(
                          child: RepaintBoundary(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                              child: _buildArea(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
