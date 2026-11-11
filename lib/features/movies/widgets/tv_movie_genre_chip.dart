import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';

/// Pastilla de género de una película: redonda, en el acento sólido (como
/// el tag de paso del PIN, "PASO 1 DE 2") y con el texto que va sobre él.
class TvMovieGenreChip extends StatelessWidget {
  final String label;

  const TvMovieGenreChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.primary,
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        // Bajado lo justo para verse centrado (ver
        // [MoaiText.opticalCenterShift]).
        child: Transform.translate(
          offset: Offset(0, MoaiText.opticalCenterShift(12)),
          child: Text(
            label,
            style: MoaiText.body(
              context,
              fontSize: 12,
              color: scheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
