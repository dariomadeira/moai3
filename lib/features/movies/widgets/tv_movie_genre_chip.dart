import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';

/// Pastilla estética para géneros de películas en Smart TV.
class TvMovieGenreChip extends StatelessWidget {
  final String label;

  const TvMovieGenreChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: MoaiText.body(
          context,
          fontSize: 12,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
