import 'dart:math' as math;

/// Fotos más anchas que esto (cine 2,39:1) quedan algo blandas al cubrir.
const double kWidestPhotoAspect = 2.4;

/// Ancho en píxeles al que decodificar una foto que se muestra con
/// `BoxFit.cover` en un recuadro de [width]×[height] puntos.
///
/// Los fondos del catálogo vienen de hasta 4096 px (8–28 MB cada uno en
/// RAM): se piden al tamaño de pantalla. Con sólo el ancho del recuadro, una
/// foto panorámica quedaba más baja que el recuadro y se agrandaba (borrosa).
/// Por eso el ancho alcanza también para cubrir el alto con fotos de hasta
/// [kWidestPhotoAspect]. Nunca se agranda una foto más chica (`ResizeImage`
/// no lo hace) ni se deforma (sólo se fija el ancho).
int coverDecodeWidth({
  required double width,
  required double height,
  required double devicePixelRatio,
}) {
  final needed = math.max(width, height * kWidestPhotoAspect);
  return (needed * devicePixelRatio).ceil();
}
