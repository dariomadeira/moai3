import 'package:flutter/material.dart';

/// Rastreador global de modales, diálogos y popups para la navegación de la app.
///
/// Se registra como `NavigatorObserver` en el router principal (GoRouter).
/// Permite saber si hay algún diálogo modal abierto para que componentes como
/// el gestor de notificaciones no interrumpan al usuario ni roben el foco del D-Pad.
class ModalRouteTracker extends NavigatorObserver with ChangeNotifier {
  ModalRouteTracker._();

  static final ModalRouteTracker instance = ModalRouteTracker._();

  int _activeModalCount = 0;
  int _manualPauseCount = 0;

  /// Retorna `true` si hay al menos un modal, diálogo o popup visible,
  /// o si las notificaciones han sido pausadas manualmente.
  bool get hasActiveModal => _activeModalCount > 0 || _manualPauseCount > 0;

  /// Cantidad actual de modales activos en la pila de navegación.
  int get activeModalCount => _activeModalCount;

  /// Pausa manualmente la cola de notificaciones (útil para flujos críticos).
  void pause() {
    final wasActive = hasActiveModal;
    _manualPauseCount++;
    if (!wasActive) {
      notifyListeners();
    }
  }

  /// Reanuda la cola de notificaciones tras una pausa manual previa.
  void resume() {
    if (_manualPauseCount > 0) {
      _manualPauseCount--;
      if (!hasActiveModal) {
        notifyListeners();
      }
    }
  }

  /// Limpia contadores para pruebas unitarias.
  @visibleForTesting
  void resetForTesting() {
    _activeModalCount = 0;
    _manualPauseCount = 0;
  }

  bool _isModalRoute(Route<dynamic> route) {
    // PopupRoute abarca DialogRoute, RawDialogRoute (showTvGeneralDialog),
    // ModalBottomSheetRoute, PopupMenuRoute, etc.
    if (route is PopupRoute) return true;
    if (route is ModalRoute && !route.opaque) return true;
    return false;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (_isModalRoute(route)) {
      final wasActive = hasActiveModal;
      _activeModalCount++;
      if (!wasActive) {
        notifyListeners();
      }
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (_isModalRoute(route)) {
      _activeModalCount = (_activeModalCount - 1).clamp(0, 9999);
      if (!hasActiveModal) {
        notifyListeners();
      }
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (_isModalRoute(route)) {
      _activeModalCount = (_activeModalCount - 1).clamp(0, 9999);
      if (!hasActiveModal) {
        notifyListeners();
      }
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    final wasActive = hasActiveModal;
    if (oldRoute != null && _isModalRoute(oldRoute)) {
      _activeModalCount = (_activeModalCount - 1).clamp(0, 9999);
    }
    if (newRoute != null && _isModalRoute(newRoute)) {
      _activeModalCount++;
    }
    if (wasActive != hasActiveModal) {
      notifyListeners();
    }
  }
}
