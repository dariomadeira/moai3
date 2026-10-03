import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:moai3/models/movie.dart';
import 'package:moai3/models/torrent_stream.dart';
import 'package:moai3/services/movie_service.dart';

/// Provider que gestiona el estado del catálogo de películas VOD y fuentes P2P (SPEC-38).
class MovieProvider extends ChangeNotifier {
  List<Movie> _movies = [];
  bool _isLoading = false;
  String? _errorMessage;

  Movie? _selectedMovie;
  List<TorrentStream> _streams = [];
  bool _isLoadingStreams = false;
  TorrentStream? _selectedStream;

  List<Movie> get movies => _movies;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Movie? get selectedMovie => _selectedMovie;
  List<TorrentStream> get streams => _streams;
  bool get isLoadingStreams => _isLoadingStreams;
  TorrentStream? get selectedStream => _selectedStream;

  /// Carga el catálogo de películas populares.
  Future<void> loadPopularMovies({
    String? tmdbApiKey,
    Future<String> Function(String url)? customFetcher,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final apiKey = tmdbApiKey ?? (dotenv.isInitialized ? dotenv.env['TMDB_API_KEY'] : null);

    try {
      _movies = await MovieService.fetchPopularMovies(
        tmdbApiKey: apiKey,
        customFetcher: customFetcher,
      );
    } catch (e) {
      _errorMessage = 'Error al cargar catálogo de películas: $e';
      _movies = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selecciona una película y busca sus fuentes de transmisión P2P en Torrentio.
  Future<void> selectMovie(
    Movie? movie, {
    Future<String> Function(String url)? customFetcher,
  }) async {
    _selectedMovie = movie;
    _streams = [];
    _selectedStream = null;
    _isLoadingStreams = false;

    if (movie == null || movie.imdbId == null || movie.imdbId!.isEmpty) {
      notifyListeners();
      return;
    }

    _isLoadingStreams = true;
    notifyListeners();

    try {
      _streams = await MovieService.fetchStreamsForMovie(
        movie.imdbId!,
        customFetcher: customFetcher,
      );
      if (_streams.isNotEmpty) {
        // Seleccionar automáticamente la fuente de mayor puntaje (Audio Latino primero)
        _selectedStream = _streams.first;
      }
    } catch (e) {
      debugPrint('[MovieProvider] Error cargando fuentes para ${movie.title}: $e');
    } finally {
      _isLoadingStreams = false;
      notifyListeners();
    }
  }

  /// Selecciona una fuente de transmisión específica de la lista.
  void selectStream(TorrentStream stream) {
    _selectedStream = stream;
    notifyListeners();
  }

  /// Limpia la selección actual.
  void clearSelection() {
    _selectedMovie = null;
    _streams = [];
    _selectedStream = null;
    _isLoadingStreams = false;
    notifyListeners();
  }
}
