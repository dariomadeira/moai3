import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Clase centralizada para la gestión de todos los íconos de la aplicación usando HugeIcons.
/// 
/// Permite mantener una única fuente de verdad para los íconos del sistema
/// y elimina la dependencia directa de `material_symbols_icons` o `Icons` en las vistas.
abstract class AppIcons {
  // ---------------------------------------------------------------------------
  // Navegación Principal & Header
  // ---------------------------------------------------------------------------
  static const List<List<dynamic>> tv = HugeIcons.strokeRoundedTv01;
  static const List<List<dynamic>> calendar = HugeIcons.strokeRoundedCalendar01;
  static const List<List<dynamic>> arcade = HugeIcons.strokeRoundedGameController01;
  static const List<List<dynamic>> settings = HugeIcons.strokeRoundedSettings01;
  static const List<List<dynamic>> search = HugeIcons.strokeRoundedSearch01;
  static const List<List<dynamic>> group = HugeIcons.strokeRoundedUserGroup;
  static const List<List<dynamic>> home = HugeIcons.strokeRoundedHome01;

  // ---------------------------------------------------------------------------
  // Reproductor de Video & Watch Party
  // ---------------------------------------------------------------------------
  static const List<List<dynamic>> play = HugeIcons.strokeRoundedPlay;
  static const List<List<dynamic>> pause = HugeIcons.strokeRoundedPause;
  static const List<List<dynamic>> volumeHigh = HugeIcons.strokeRoundedVolumeHigh;
  static const List<List<dynamic>> volumeOff = HugeIcons.strokeRoundedVolumeMute01;
  static const List<List<dynamic>> micOn = HugeIcons.strokeRoundedMic01;
  static const List<List<dynamic>> micOff = HugeIcons.strokeRoundedMicOff01;
  static const List<List<dynamic>> subtitles = HugeIcons.strokeRoundedSubtitle;
  static const List<List<dynamic>> fullscreen = HugeIcons.strokeRoundedMaximize01;
  static const List<List<dynamic>> exitFullscreen = HugeIcons.strokeRoundedMinimize01;
  static const List<List<dynamic>> skipNext = HugeIcons.strokeRoundedNext;
  static const List<List<dynamic>> watchParty = HugeIcons.strokeRoundedUserGroup;

  // ---------------------------------------------------------------------------
  // Ajustes, Amigos & Diálogos
  // ---------------------------------------------------------------------------
  static const List<List<dynamic>> person = HugeIcons.strokeRoundedUser;
  static const List<List<dynamic>> addFriend = HugeIcons.strokeRoundedUserAdd01;
  static const List<List<dynamic>> removeFriend = HugeIcons.strokeRoundedUserRemove01;
  static const List<List<dynamic>> friends = HugeIcons.strokeRoundedUserGroup;
  static const List<List<dynamic>> lock = HugeIcons.strokeRoundedLock;
  static const List<List<dynamic>> unlock = HugeIcons.strokeRoundedLockOpen;
  static const List<List<dynamic>> gamepad = HugeIcons.strokeRoundedGamepad;
  static const List<List<dynamic>> voiceTest = HugeIcons.strokeRoundedWave;
  static const List<List<dynamic>> update = HugeIcons.strokeRoundedRefresh;
  static const List<List<dynamic>> download = HugeIcons.strokeRoundedDownload01;
  static const List<List<dynamic>> info = HugeIcons.strokeRoundedInformationCircle;
  static const List<List<dynamic>> pin = HugeIcons.strokeRoundedKey01;
  static const List<List<dynamic>> time = HugeIcons.strokeRoundedClock01;
  static const List<List<dynamic>> hourglass = HugeIcons.strokeRoundedHourglass;

  // ---------------------------------------------------------------------------
  // Acciones, Listas & General
  // ---------------------------------------------------------------------------
  static const List<List<dynamic>> star = HugeIcons.strokeRoundedStar;
  static const List<List<dynamic>> starFilled = HugeIcons.strokeRoundedStar;
  static const List<List<dynamic>> folder = HugeIcons.strokeRoundedFolder01;
  static const List<List<dynamic>> delete = HugeIcons.strokeRoundedDelete01;
  static const List<List<dynamic>> edit = HugeIcons.strokeRoundedPencilEdit01;
  static const List<List<dynamic>> close = HugeIcons.strokeRoundedCancel01;
  static const List<List<dynamic>> check = HugeIcons.strokeRoundedTick01;
  static const List<List<dynamic>> sortAlpha = HugeIcons.strokeRoundedSortingAZ01;
  static const List<List<dynamic>> arrowLeft = HugeIcons.strokeRoundedArrowLeft01;
  static const List<List<dynamic>> arrowRight = HugeIcons.strokeRoundedArrowRight01;
  static const List<List<dynamic>> arrowUp = HugeIcons.strokeRoundedArrowUp01;
  static const List<List<dynamic>> arrowDown = HugeIcons.strokeRoundedArrowDown01;
  static const List<List<dynamic>> chevronRight = HugeIcons.strokeRoundedArrowRight01;
  static const List<List<dynamic>> chevronLeft = HugeIcons.strokeRoundedArrowLeft01;
  static const List<List<dynamic>> add = HugeIcons.strokeRoundedAdd01;
  static const List<List<dynamic>> remove = HugeIcons.strokeRoundedRemove01;
  static const List<List<dynamic>> filter = HugeIcons.strokeRoundedFilter;
  static const List<List<dynamic>> globe = HugeIcons.strokeRoundedGlobe;
  static const List<List<dynamic>> category = HugeIcons.strokeRoundedGrid;
  static const List<List<dynamic>> channel = HugeIcons.strokeRoundedTv01;
  static const List<List<dynamic>> plugin = HugeIcons.strokeRoundedPlug;

  // ---------------------------------------------------------------------------
  // Utilidades, Alertas & Diálogos Adicionales
  // ---------------------------------------------------------------------------
  static const List<List<dynamic>> user = HugeIcons.strokeRoundedUser;
  static const List<List<dynamic>> badge = HugeIcons.strokeRoundedBadge;
  static const List<List<dynamic>> keyboard = HugeIcons.strokeRoundedKeyboard;
  static const List<List<dynamic>> error = HugeIcons.strokeRoundedAlertCircle;
  static const List<List<dynamic>> warning = HugeIcons.strokeRoundedTriangleAlert;
  static const List<List<dynamic>> email = HugeIcons.strokeRoundedMail01;
  static const List<List<dynamic>> stop = HugeIcons.strokeRoundedStop;
  static const List<List<dynamic>> record = HugeIcons.strokeRoundedRecord;
  static const List<List<dynamic>> idea = HugeIcons.strokeRoundedIdea01;
  static const List<List<dynamic>> backspace = HugeIcons.strokeRoundedDelete01;
  static const List<List<dynamic>> wifi = HugeIcons.strokeRoundedWifi01;
  static const List<List<dynamic>> trophy = HugeIcons.strokeRoundedTrophy;
  static const List<List<dynamic>> help = HugeIcons.strokeRoundedHelpCircle;
  static const List<List<dynamic>> view = HugeIcons.strokeRoundedView;
  static const List<List<dynamic>> viewOff = HugeIcons.strokeRoundedViewOffSlash;
  static const List<List<dynamic>> copy = HugeIcons.strokeRoundedCopy01;
  static const List<List<dynamic>> share = HugeIcons.strokeRoundedShare01;
  static const List<List<dynamic>> heart = HugeIcons.strokeRoundedFavourite;
}

/// Helper Widget para renderizar íconos de AppIcons de forma limpia y concisa.
class AppIcon extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color? color;
  final double? size;

  const AppIcon({
    super.key,
    required this.icon,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return HugeIcon(
      icon: icon,
      color: color ?? IconTheme.of(context).color ?? Colors.white,
      size: size ?? IconTheme.of(context).size ?? 24.0,
    );
  }
}
