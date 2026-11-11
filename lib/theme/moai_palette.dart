import 'package:flutter/material.dart';

/// Los colores del cristal y la tinta fija que no salen del [ColorScheme]:
/// uno por modo. Los del claro son exactamente los que había escritos en
/// cada pieza (la foto del 2026-11-10); no se tocan sin querer cambiar el
/// claro (los tests golden lo vigilan).
///
/// REDISEÑO oscuro (2026-11-10): "visionOS oscuro", vidrio ahumado sobre
/// el fondo oscuro: blanco muy tenue en vez de blanco a medias, filos de
/// luz apagados y sombras más negras.
@immutable
class MoaiPalette extends ThemeExtension<MoaiPalette> {
  const MoaiPalette({
    required this.glassCard,
    required this.glassChip,
    required this.glassRim,
    required this.specularRim,
    required this.glassShadow,
    required this.panelShadow,
    required this.frostedVeil,
    required this.frostedRim,
    required this.tagFill,
    required this.tagRim,
    required this.inkSoft,
    required this.inkMuted,
    required this.inkIdle,
    required this.watched,
  });

  /// Relleno de las piezas sólidas sobre el panel ([MoaiGlass] `solid`,
  /// botones de cristal en reposo).
  final Color glassCard;

  /// Relleno de las piezas chicas ([MoaiGlass] sin `solid`).
  final Color glassChip;

  /// Filo de luz parejo (borde sin foco).
  final Color glassRim;

  /// Filo de luz con degradado: arriba a la izquierda, medio, abajo.
  final List<Color> specularRim;

  /// Sombra de las piezas elevadas.
  final Color glassShadow;

  /// Sombra de los paneles grandes.
  final Color panelShadow;

  /// Velo del vidrio esmerilado: arriba y abajo.
  final List<Color> frostedVeil;

  /// Borde del vidrio esmerilado: arriba, costados (2) y abajo.
  final List<Color> frostedRim;

  /// Etiquetas de cristal ("1400 canales"): relleno y filo.
  final Color tagFill;
  final Color tagRim;

  /// Tinta suave: subtítulo del saludo, fecha del reloj, título de la
  /// pestaña del panel (era `0xFF2D3625`).
  final Color inkSoft;

  /// Gris de los logos y del ícono de la pestaña del panel (era
  /// `0xFF3C4250`).
  final Color inkMuted;

  /// Íconos del rail y pestañas de TV sin foco (era `0xFF1A1D24`).
  final Color inkIdle;

  /// Número de un capítulo o temporada ya vistos (series): verde que se lee
  /// sobre el cristal de cada modo.
  final Color watched;

  static const MoaiPalette light = MoaiPalette(
    glassCard: Color(0x73FFFFFF), // blanco al 45 %
    glassChip: Color(0x99FFFFFF), // blanco al 60 %
    glassRim: Color(0x99FFFFFF), // filo de luz al 60 %
    specularRim: [
      Color(0xF2FFFFFF), // blanco al 95 % arriba a la izquierda
      Color(0x80FFFFFF), // al 50 % en el medio
      Color(0x1AFFFFFF), // al 10 % abajo a la derecha
    ],
    glassShadow: Color(0x14000000), // negro al 8 %
    panelShadow: Color(0x2E000000), // negro al 18 %
    frostedVeil: [
      Color(0x61FFFFFF), // blanco al 38 % arriba
      Color(0x38FFFFFF), // al 22 % abajo
    ],
    frostedRim: [
      Color(0xB3FFFFFF), // arriba: 70 %
      Color(0x1FFFFFFF), // costados: 12 %
      Color(0x14FFFFFF),
      Color(0x47FFFFFF), // abajo: 28 %
    ],
    tagFill: Color(0x99FFFFFF), // blanco al 60 %
    tagRim: Color(0xB3FFFFFF), // filo de luz al 70 %
    inkSoft: Color(0xFF2D3625),
    inkMuted: Color(0xFF3C4250),
    inkIdle: Color(0xFF1A1D24),
    watched: Color(0xFF15803D),
  );

  static const MoaiPalette dark = MoaiPalette(
    glassCard: Color(0x14FFFFFF), // blanco al 8 %
    glassChip: Color(0x1FFFFFFF), // al 12 %
    glassRim: Color(0x29FFFFFF), // filo al 16 %
    specularRim: [
      Color(0x59FFFFFF), // al 35 % arriba a la izquierda
      Color(0x1FFFFFFF), // al 12 % en el medio
      Color(0x08FFFFFF), // al 3 % abajo a la derecha
    ],
    glassShadow: Color(0x59000000), // negro al 35 %
    panelShadow: Color(0x80000000), // negro al 50 %
    frostedVeil: [
      Color(0x1AFFFFFF), // blanco al 10 % arriba
      Color(0x0AFFFFFF), // al 4 % abajo
    ],
    frostedRim: [
      Color(0x4DFFFFFF), // arriba: 30 %
      Color(0x0FFFFFFF), // costados: 6 %
      Color(0x0AFFFFFF),
      Color(0x1FFFFFFF), // abajo: 12 %
    ],
    tagFill: Color(0x1AFFFFFF), // blanco al 10 %
    tagRim: Color(0x29FFFFFF), // filo al 16 %
    inkSoft: Color(0xFFC9CED8),
    inkMuted: Color(0xFFB4BAC6),
    inkIdle: Color(0xFFE3E6EC),
    watched: Color(0xFF4ADE80),
  );

  /// La del tema; sin tema de la app (algunos tests), la del claro.
  static MoaiPalette of(BuildContext context) =>
      Theme.of(context).extension<MoaiPalette>() ?? light;

  /// La del modo de [scheme], para lo que se arma sin contexto (las
  /// decoraciones que reciben el esquema).
  static MoaiPalette ofScheme(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark ? dark : light;

  @override
  MoaiPalette copyWith({
    Color? glassCard,
    Color? glassChip,
    Color? glassRim,
    List<Color>? specularRim,
    Color? glassShadow,
    Color? panelShadow,
    List<Color>? frostedVeil,
    List<Color>? frostedRim,
    Color? tagFill,
    Color? tagRim,
    Color? inkSoft,
    Color? inkMuted,
    Color? inkIdle,
    Color? watched,
  }) => MoaiPalette(
    glassCard: glassCard ?? this.glassCard,
    glassChip: glassChip ?? this.glassChip,
    glassRim: glassRim ?? this.glassRim,
    specularRim: specularRim ?? this.specularRim,
    glassShadow: glassShadow ?? this.glassShadow,
    panelShadow: panelShadow ?? this.panelShadow,
    frostedVeil: frostedVeil ?? this.frostedVeil,
    frostedRim: frostedRim ?? this.frostedRim,
    tagFill: tagFill ?? this.tagFill,
    tagRim: tagRim ?? this.tagRim,
    inkSoft: inkSoft ?? this.inkSoft,
    inkMuted: inkMuted ?? this.inkMuted,
    inkIdle: inkIdle ?? this.inkIdle,
    watched: watched ?? this.watched,
  );

  @override
  MoaiPalette lerp(MoaiPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> l(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) c(a[i], b[i]),
    ];
    return MoaiPalette(
      glassCard: c(glassCard, other.glassCard),
      glassChip: c(glassChip, other.glassChip),
      glassRim: c(glassRim, other.glassRim),
      specularRim: l(specularRim, other.specularRim),
      glassShadow: c(glassShadow, other.glassShadow),
      panelShadow: c(panelShadow, other.panelShadow),
      frostedVeil: l(frostedVeil, other.frostedVeil),
      frostedRim: l(frostedRim, other.frostedRim),
      tagFill: c(tagFill, other.tagFill),
      tagRim: c(tagRim, other.tagRim),
      inkSoft: c(inkSoft, other.inkSoft),
      inkMuted: c(inkMuted, other.inkMuted),
      inkIdle: c(inkIdle, other.inkIdle),
      watched: c(watched, other.watched),
    );
  }
}
