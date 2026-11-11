import 'package:flutter/material.dart';

/// El fondo de toda la app: una imagen fija por modo, sin tinte ni acento.
///
/// El claro sale de `assets_src/backgrounds/new_font.jpg` desenfocado
/// (`gen_background_new.py`); el oscuro, del claro
/// (`gen_background_dark.py`). Cada uno tiene su copia desenfocada a la
/// mitad de resolución, la del vidrio esmerilado y el loading: si cambia un
/// fondo, se regeneran los dos.
class MoaiAmbientBackground extends StatefulWidget {
  const MoaiAmbientBackground({super.key});

  static const String lightAsset = 'assets/images/background_light.webp';
  static const String lightBlurredAsset =
      'assets/images/background_light_blur.webp';
  static const String darkAsset = 'assets/images/background_dark.webp';
  static const String darkBlurredAsset =
      'assets/images/background_dark_blur.webp';

  /// El fondo de cada modo.
  static String assetFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkAsset : lightAsset;

  /// La copia desenfocada del fondo de cada modo.
  static String blurredAssetFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkBlurredAsset : lightBlurredAsset;

  @override
  State<MoaiAmbientBackground> createState() => _MoaiAmbientBackgroundState();
}

class _MoaiAmbientBackgroundState extends State<MoaiAmbientBackground> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(
      AssetImage(MoaiAmbientBackground.assetFor(Theme.of(context).brightness)),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Decodificada al ancho de la pantalla, no a su tamaño real, para no
    // gastar memoria de más en el TV.
    final screen = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final asset = MoaiAmbientBackground.assetFor(Theme.of(context).brightness);
    // Al cambiar de modo, un fundido de una imagen a la otra.
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Image.asset(
          asset,
          key: ValueKey(asset),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: screen.width > 0 ? (screen.width * dpr).round() : null,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
