import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';

/// Pastilla de valor para filas de ajustes (apodo, código de usuario).
class TvValueChip extends StatelessWidget {
  final String text;
  final bool isFocused;

  const TvValueChip({
    super.key,
    required this.text,
    required this.isFocused,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isFocused ? scheme.onPrimary : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: MoaiText.body(
          context,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isFocused ? scheme.primary : scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
