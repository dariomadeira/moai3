import 'package:flutter/material.dart';
import 'package:moai3/engine/moai_engine_player.dart';
import 'package:moai3/theme/moai_text.dart';

/// Renderizador de video con el motor Kotlin nativo (widget `Texture`).
class EnginePlayerView extends StatelessWidget {
  final MoaiEngineController controller;
  final bool showBuffering;
  final BoxFit fit;

  /// Detrás del video: se ve en las franjas cuando [fit] no lo estira a
  /// toda la pantalla (p. ej. una película más ancha que 16:9). Por defecto,
  /// el color de superficie del tema.
  final Color? background;

  const EnginePlayerView({
    super.key,
    required this.controller,
    this.showBuffering = false,
    this.fit = BoxFit.cover,
    this.background,
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
      color: background ?? scheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (width > 0 && height > 0)
            FittedBox(
              fit: fit,
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