import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Pastilla estética para géneros de películas en Smart TV.
class TvMovieGenreChip extends StatelessWidget {
  final String label;

  const TvMovieGenreChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final glass = MoaiGlassScope.enabledOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
      decoration: glass
          ? moaiGlassChipDecoration(scheme, radius: 12)
          : BoxDecoration(
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
          color: glass ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
