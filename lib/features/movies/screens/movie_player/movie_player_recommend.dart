part of '../movie_player_screen.dart';

/// ¿La recomendarías?: cuándo se pregunta, sus teclas y la respuesta.
extension _MoviePlayerRecommend on _MoviePlayerScreenState {
  void _maybeAskRecommendation() {
    if (_recommendSettled || !widget.saveProgress) return;
    // Series: sólo en el último capítulo de cada temporada.
    final series = widget.series;
    if (series != null && !series.isLastOfSeason) {
      _recommendSettled = true;
      return;
    }
    final remaining = _totalDuration - _currentPosition;
    if (_totalDuration <= _MoviePlayerScreenState._recommendWindow ||
        remaining > _MoviePlayerScreenState._recommendWindow ||
        remaining <= Duration.zero) {
      return;
    }
    // Sin pisar lo que se esté usando: se reintenta en la próxima vuelta.
    if (_isBuffering ||
        !_isPlaying ||
        _hasError ||
        _openMenu != null ||
        _selectedMenu != null ||
        _scrubTarget != null) {
      return;
    }
    _recommendSettled = true;
    if (series != null) {
      // Una vez por temporada, aunque ya se haya votado otra.
      final recommendations = context.read<SeriesRecommendationsProvider?>();
      if (recommendations == null ||
          !recommendations.shouldAskSeason(
            series.recommendationKey,
            series.seasonNumber,
          )) {
        return;
      }
    } else {
      final recommendations = context.read<MovieRecommendationsProvider?>();
      if (recommendations == null ||
          !recommendations.canRecommend ||
          !recommendations.shouldAsk(widget.movie.contentId)) {
        return;
      }
    }
    // Arranca en Cancelar: un OK distraído no recomienda.
    _update(() => _recommendAnswer = MovieRecommendAnswer.cancel);
    _recommendTimer = Timer(
      _MoviePlayerScreenState._recommendVisibleFor,
      _closeRecommendPrompt,
    );
  }

  void _closeRecommendPrompt() {
    _recommendTimer?.cancel();
    if (mounted) _update(() => _recommendAnswer = null);
  }

  KeyEventResult _onRecommendKey(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    final answer = _recommendAnswer!;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final step = key == LogicalKeyboardKey.arrowLeft ? -1 : 1;
      const answers = MovieRecommendAnswer.values;
      _update(() {
        _recommendAnswer =
            answers[(answer.index + step).clamp(0, answers.length - 1)];
      });
    } else if (TvKeyHandler.isActionKey(key)) {
      _applyRecommendAnswer(answer);
    } else if (_MoviePlayerScreenState._isBackKey(key)) {
      _closeRecommendPrompt();
    }
    return KeyEventResult.handled;
  }

  void _applyRecommendAnswer(MovieRecommendAnswer answer) {
    _closeRecommendPrompt();
    final series = widget.series;
    if (series != null) return _applySeriesAnswer(series, answer);
    final recommendations = context.read<MovieRecommendationsProvider?>();
    if (recommendations == null) return;
    switch (answer) {
      case MovieRecommendAnswer.yes:
        unawaited(recommendations.setVote(widget.movie, MovieVote.up));
        MoaiSnackBar.show(
          context,
          message: LocaleKeys.movies_recommend_sent.tr(),
          icon: MoaiIcons.vodRecommend,
        );
      case MovieRecommendAnswer.no:
        unawaited(recommendations.setVote(widget.movie, MovieVote.down));
      case MovieRecommendAnswer.cancel:
        break;
    }
  }

  /// Series: el voto es de la serie y el 👍 lleva la temporada que se
  /// terminó ("hasta T3"); 👎 saca la recomendación. Cancelar vuelve a
  /// preguntar la próxima vez que se termine esta temporada.
  void _applySeriesAnswer(SeriesPlaylist series, MovieRecommendAnswer answer) {
    final recommendations = context.read<SeriesRecommendationsProvider?>();
    if (recommendations == null || answer == MovieRecommendAnswer.cancel) {
      return;
    }
    final up = answer == MovieRecommendAnswer.yes;
    unawaited(
      recommendations.setVote(
        series.recommendationItem,
        up ? MovieVote.up : MovieVote.down,
        extra: {SeriesRecommendationsApi.seasonKey: series.seasonNumber},
      ),
    );
    unawaited(
      recommendations.markAskedSeason(
        series.recommendationKey,
        series.seasonNumber,
      ),
    );
    if (up) {
      MoaiSnackBar.show(
        context,
        message: LocaleKeys.movies_recommend_sent.tr(),
        icon: MoaiIcons.vodRecommend,
      );
    }
  }
}
