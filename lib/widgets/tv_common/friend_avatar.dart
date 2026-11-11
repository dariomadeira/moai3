import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';

/// Avatares de amigos: uno de los moais de `assets/images/avatars/`.
abstract final class FriendAvatars {
  static const int count = 9;

  /// El avatar de [userCode]: siempre el mismo para el mismo usuario, en
  /// cualquier aparato y versión (FNV-1a, no `hashCode`, que puede cambiar).
  /// Con más de [count] amigos se repiten.
  static String assetFor(String userCode) {
    var hash = 0x811c9dc5;
    for (final unit in userCode.trim().toUpperCase().codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return 'assets/images/avatars/moai_${hash % count + 1}.webp';
  }
}

/// Avatar redondo con el moai del amigo y el punto de estado: verde si está
/// conectado y gris si no (el moai se apaga un poco).
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({
    super.key,
    required this.userCode,
    this.online = true,
    this.size = 44,
  });

  final String userCode;
  final bool online;
  final double size;

  static const Color onlineColor = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final dot = (size * 0.3).roundToDouble();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: online ? 1 : 0.55,
            child: ClipOval(
              child: Image.asset(
                FriendAvatars.assetFor(userCode),
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: (size * dpr).round(),
                // Si falta la imagen, el círculo vacío en vez del error.
                errorBuilder: (_, _, _) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: SizedBox.square(dimension: size),
                ),
              ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: online ? onlineColor : scheme.outline,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
