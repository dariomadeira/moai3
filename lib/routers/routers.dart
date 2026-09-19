import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moai3/features/bootstrap/screens/overlap_config_screen.dart';
import 'package:moai3/features/home/screens/home_screen.dart';
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

/// Router offline de moai3. Abre directamente en /home con estado vacio.
GoRouter createRouter(TvSettingsProvider tvSettingsProvider) {
  return GoRouter(
    initialLocation: tvSettingsProvider.hasOverlapConfig ? '/home' : '/overlap',
    refreshListenable: tvSettingsProvider,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!tvSettingsProvider.hasOverlapConfig) {
        if (loc != '/overlap') {
          return '/overlap';
        }
        return null;
      }
      if (loc == '/' || loc == '/boot' || loc == '/server') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/overlap',
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
        path: '/',
        redirect: (_, _) => '/home',
      ),
    ],
  );
}

