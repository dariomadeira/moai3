import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget de Flutter que integra la vista nativa de Android (SurfaceView)
/// donde se renderiza el video del juego Arcade emulado.
class ArcadeViewContainer extends StatelessWidget {
  final String viewType;
  final Map<String, dynamic> creationParams;

  const ArcadeViewContainer({
    super.key,
    this.viewType = 'com.infomak.moai/arcade_view',
    this.creationParams = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: viewType,
        layoutDirection: TextDirection.ltr,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          if (kDebugMode) {
            debugPrint('[ArcadeViewContainer] PlatformView nativa creada id: $id');
          }
        },
      );
    }

    return Center(
      child: Text(
        'El emulador de Arcade requiere un dispositivo Android.',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
