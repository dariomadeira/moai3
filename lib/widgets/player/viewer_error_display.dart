import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';

/// Estado de error compacto del visor TV.
class ViewerErrorDisplay extends StatelessWidget {
  final String errorMessage;

  const ViewerErrorDisplay({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return ColoredBox(
      color: scheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: scheme.error),
              const SizedBox(height: 12),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: MoaiText.body(
                  context,
                  color: scheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'player_error_retry_hint'.tr(),
                textAlign: TextAlign.center,
                style: MoaiText.body(
                  context,
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

