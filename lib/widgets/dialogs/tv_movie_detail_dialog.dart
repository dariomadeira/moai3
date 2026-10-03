import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/models/movie.dart';
import 'package:moai3/models/torrent_stream.dart';
import 'package:moai3/state/movie_provider.dart';
import 'package:moai3/theme/moai_text.dart';

/// Diálogo modal de detalles de película y selección de fuentes P2P (SPEC-38).
class TvMovieDetailDialog extends StatefulWidget {
  final Movie movie;
  final ValueChanged<TorrentStream>? onPlayStream;

  const TvMovieDetailDialog({
    super.key,
    required this.movie,
    this.onPlayStream,
  });

  static Future<void> show(
    BuildContext context,
    Movie movie, {
    ValueChanged<TorrentStream>? onPlayStream,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => TvMovieDetailDialog(
        movie: movie,
        onPlayStream: onPlayStream,
      ),
    );
  }

  @override
  State<TvMovieDetailDialog> createState() => _TvMovieDetailDialogState();
}

class _TvMovieDetailDialogState extends State<TvMovieDetailDialog> {
  final FocusNode _closeButtonFocus = FocusNode(debugLabel: 'movie_detail_close');
  final FocusNode _playButtonFocus = FocusNode(debugLabel: 'movie_detail_play');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MovieProvider>().selectMovie(widget.movie);
        _playButtonFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _closeButtonFocus.dispose();
    _playButtonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<MovieProvider>();

    return Dialog(
      backgroundColor: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 720,
        height: 480,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Poster Image (Left)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 220,
                  child: widget.movie.posterPath != null &&
                          widget.movie.posterPath!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.movie.posterPath!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: scheme.surfaceContainerLowest,
                          child: Icon(Icons.movie, size: 64, color: scheme.outline),
                        ),
                ),
              ),

              const SizedBox(width: 20),

              // Details & Streams (Right)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      widget.movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MoaiText.display(
                        context,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Badges (Rating, Year)
                    Row(
                      children: [
                        if (widget.movie.voteAverage > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade900.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber, width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  widget.movie.voteAverage.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (widget.movie.releaseDate != null)
                          Text(
                            widget.movie.releaseDate!,
                            style: MoaiText.body(
                              context,
                              color: scheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Overview / Synopsis
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        child: Text(
                          widget.movie.overview.isNotEmpty
                              ? widget.movie.overview
                              : 'Sin descripción disponible.',
                          style: MoaiText.body(
                            context,
                            fontSize: 13,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Fuentes P2P Header
                    Row(
                      children: [
                        Icon(Icons.stream, size: 16, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Fuentes de reproducción (Audio Latino automatizado):',
                          style: MoaiText.body(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Stream List / Loader
                    Expanded(
                      flex: 2,
                      child: provider.isLoadingStreams
                          ? const Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Buscando mejores fuentes P2P...'),
                                ],
                              ),
                            )
                          : provider.streams.isEmpty
                              ? Text(
                                  'No se encontraron fuentes de transmisión disponibles.',
                                  style: MoaiText.body(
                                    context,
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: provider.streams.length,
                                  itemBuilder: (context, index) {
                                    final stream = provider.streams[index];
                                    final isSelected =
                                        provider.selectedStream?.infoHash == stream.infoHash;

                                    return ListTile(
                                      dense: true,
                                      selected: isSelected,
                                      onTap: () => provider.selectStream(stream),
                                      leading: Icon(
                                        stream.hasLatinoAudio
                                            ? Icons.record_voice_over
                                            : Icons.subtitles,
                                        color: stream.hasLatinoAudio
                                            ? Colors.greenAccent
                                            : scheme.onSurfaceVariant,
                                      ),
                                      title: Text(
                                        stream.quality,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                        '👤 ${stream.seeders} semillas • ${stream.hasLatinoAudio ? 'Español Latino' : 'Original'}',
                                      ),
                                      trailing: isSelected
                                          ? Icon(Icons.check_circle, color: scheme.primary)
                                          : null,
                                    );
                                  },
                                ),
                    ),

                    const SizedBox(height: 12),

                    // Action Buttons (Play / Close)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          focusNode: _closeButtonFocus,
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cerrar'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          focusNode: _playButtonFocus,
                          onPressed: provider.selectedStream != null
                              ? () {
                                  Navigator.of(context).pop();
                                  if (widget.onPlayStream != null) {
                                    widget.onPlayStream!(provider.selectedStream!);
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Reproducir en TV'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
