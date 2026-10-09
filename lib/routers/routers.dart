import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moai3/features/blocked/screens/blocked_screen.dart';
import 'package:moai3/features/bootstrap/screens/overlap_config_screen.dart';
import 'package:moai3/features/games/screens/arcade_screen.dart';
import 'package:moai3/features/home/screens/home_screen.dart';
import 'package:moai3/features/loading/screens/loading_screen.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/modal_route_tracker.dart';
import 'package:moai3/services/supabase_presence_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';

CustomTransitionPage<void> _fadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

/// Router de moai3 con control de acceso, presencia y arranque (SPEC-22).
GoRouter createRouter(
  TvSettingsProvider tvSettingsProvider, {
  required DeviceIdentityService identityService,
  required SupabasePresenceService presenceService,
}) {
  return GoRouter(
    observers: [ModalRouteTracker.instance],
    initialLocation: '/loading',
    refreshListenable: tvSettingsProvider,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (loc == '/' || loc == '/boot' || loc == '/server') {
        return '/loading';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        name: 'loading',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: LoadingScreen(
            identityService: identityService,
            presenceService: presenceService,
          ),
        ),
      ),
      GoRoute(
        path: '/blocked',
        name: 'blocked',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: BlockedScreen(
            blockReason: state.extra as String?,
          ),
        ),
      ),
      GoRoute(
        path: '/overlap',
        name: 'overlap',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const OverlapConfigScreen(),
        ),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/arcade/game',
        name: 'arcade_game',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: ArcadeScreen(
            initialRomPath: state.extra as String?,
          ),
        ),
      ),
    ],
  );
}
