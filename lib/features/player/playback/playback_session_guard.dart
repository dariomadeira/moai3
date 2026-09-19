/// Invalida intentos de reproducción obsoletos cuando cambia el canal o el widget.
class PlaybackSessionGuard {
  int _generation = 0;
  bool _disposed = false;

  int begin() => ++_generation;

  bool isCurrent(int session) => !_disposed && session == _generation;

  void dispose() {
    _disposed = true;
    _generation++;
  }
}

