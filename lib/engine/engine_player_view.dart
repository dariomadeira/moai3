import 'package:flutter/material.dart';
import 'package:moai3/engine/moai_engine_player.dart';
import 'package:moai3/theme/moai_text.dart';

/// Renderizador de video con el motor Kotlin nativo (widget `Texture`).
class EnginePlayerView extends StatelessWidget {
  final MoaiEngineController controller;
  final bool showBuffering;

  const EnginePlayerView({
    super.key,
    required this.controller,
    this.showBuffering = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final textureId = controller.textureId;
    final width = controller.event.videoWidth ?? 0;
    final height = controller.event.videoHeight ?? 0;

    if (textureId == null) {
      return Center(
        child: CircularProgressIndicator(color: scheme.primary),
      );
    }

    return ColoredBox(
      color: scheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (width > 0 && height > 0)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: width.toDouble(),
                height: height.toDouble(),
                child: Texture(textureId: textureId),
              ),
            )
          else
            Texture(textureId: textureId),
          if (showBuffering)
            ColoredBox(
              color: scheme.surface.withValues(alpha: 0.5),
              child: Center(
                child: CircularProgressIndicator(color: scheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}