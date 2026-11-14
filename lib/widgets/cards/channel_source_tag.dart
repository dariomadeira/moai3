import 'package:flutter/material.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/theme/moai_text.dart';

/// Etiqueta de la fuente de un canal ("AR", "DADDY"): pastilla del color de
/// la fuente con el nombre corto. La usan la lista
/// de canales de un evento ([NewChannelCard]) y la grilla de canales.
class ChannelSourceTag extends StatelessWidget {
  const ChannelSourceTag({super.key, required this.channel, required this.tag});

  final Channel channel;

  /// El nombre corto, ya en mayúsculas.
  final String tag;

  static const double _fontSize = MoaiText.sizeDense;

  /// Colores de las etiquetas de fuente: cada fuente toma siempre el mismo
  /// (según su id), así "AR" y "DADDY" se distinguen de un vistazo.
  static const List<Color> _sourceColors = [
    Color(0xFF3730A3), // índigo
    Color(0xFF0F8A7E), // verde azulado
    Color(0xFFC026D3), // fucsia
    Color(0xFFEA580C), // naranja
    Color(0xFF2563EB), // azul
    Color(0xFF9D1933), // bordó
  ];

  Color _sourceColor() {
    final key = channel.pluginId ?? channel.pluginTag ?? '';
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return _sourceColors[hash % _sourceColors.length];
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: _sourceColor(),
        shape: const StadiumBorder(),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Transform.translate(
          offset: Offset(0, MoaiText.opticalCenterShift(_fontSize)),
          child: Text(
            tag,
            maxLines: 1,
            style: MoaiText.body(
              context,
              fontSize: _fontSize,
              height: 1.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
