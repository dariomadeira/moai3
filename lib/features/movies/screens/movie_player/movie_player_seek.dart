part of '../movie_player_screen.dart';

/// Avanzar y retroceder: el scrub con las flechas y el salto final.
extension _MoviePlayerSeek on _MoviePlayerScreenState {
  /// ←/→: mueve el destino de la búsqueda sin tocar el video todavía.
  /// Mantenida ([repeat]) acelera.
  void _scrub({required bool forward, required bool repeat}) {
    if (_totalDuration <= Duration.zero) return;
    _scrubRepeats = repeat ? _scrubRepeats + 1 : 0;
    final target = MovieScrub.target(
      from: _scrubTarget ?? _currentPosition,
      forward: forward,
      repeats: _scrubRepeats,
      total: _totalDuration,
    );
    _osdTimer?.cancel();
    _update(() {
      _showOsd = true;
      _scrubTarget = target;
    });
    _scrubCommitTimer?.cancel();
    _scrubCommitTimer = Timer(
      _MoviePlayerScreenState._scrubCommitDelay,
      _commitScrub,
    );
  }

  /// Salta al destino de la búsqueda (una sola vez).
  void _commitScrub() {
    _scrubCommitTimer?.cancel();
    final target = _scrubTarget;
    if (target == null || !mounted) return;
    _update(() => _scrubTarget = null);
    _seekTo(target);
    _resetOsdTimer();
  }

  void _cancelScrub() {
    _scrubCommitTimer?.cancel();
    if (_scrubTarget != null && mounted) {
      _update(() => _scrubTarget = null);
    }
  }

  Future<void> _seekTo(Duration target) async {
    if (_totalDuration > Duration.zero &&
        target >= _totalDuration - _MoviePlayerScreenState._recommendWindow) {
      _recommendSettled = true;
    }
    _beforeLastSeek = _currentPosition;
    _lastSeekAt = DateTime.now();
    _seekSettlesAt = DateTime.now().add(const Duration(seconds: 3));
    _update(() => _currentPosition = target);
    if (_titan.active) {
      // Primero salta Ranger y después el reproductor: mientras, cargando.
      _update(() => _isBuffering = true);
      await _titan.beforeSeek(target);
      if (!mounted) return;
    }
    await _engine.seekTo(target);
  }
}
