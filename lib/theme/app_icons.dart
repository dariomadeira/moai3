import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:reicon_flutter/reicon_flutter.dart';

abstract class AppIcons {
  /// Icono de Control Remoto (Reicon outline remote2)
  static Widget remote({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color;

        return SvgPicture.string(
          reiconSvg(Reicon.outline.remote2),
          width: finalSize,
          height: finalSize,
          colorFilter: finalColor != null
              ? ColorFilter.mode(finalColor, BlendMode.srcIn)
              : null,
        );
      },
    );
  }

  /// Icono de Depuración (Hugeicons Bug02)
  static Widget debugLog({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedBug02,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Etiquetas de Canales (Hugeicons Tag01)
  static Widget channelLabels({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedTag01,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Contenido para Adultos (Hugeicons LockComputer)
  static Widget adultContent({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedLockComputer,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Fuentes / Extensiones (Hugeicons Puzzle)
  static Widget sources({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedPuzzle,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Zona Horaria / Desfase UTC (Hugeicons MapsGlobal01)
  static Widget utcOffset({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedMapsGlobal01,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Notificaciones / Avisar antes (Hugeicons BellRing)
  static Widget notifyLead({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedBellRing,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Duración del aviso (Hugeicons StopWatch)
  static Widget snackDuration({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedStopWatch,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Configuración de la Agenda (Reicon outline calendarEdit)
  static Widget agendaConfig({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color;

        return SvgPicture.string(
          reiconSvg(Reicon.outline.calendarEdit),
          width: finalSize,
          height: finalSize,
          colorFilter: finalColor != null
              ? ColorFilter.mode(finalColor, BlendMode.srcIn)
              : null,
        );
      },
    );
  }

  /// Icono de Miremos Juntos / Watch Party (Reicon outline userSpeak2)
  static Widget watchParty({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color;

        return SvgPicture.string(
          reiconSvg(Reicon.outline.userSpeak2),
          width: finalSize,
          height: finalSize,
          colorFilter: finalColor != null
              ? ColorFilter.mode(finalColor, BlendMode.srcIn)
              : null,
        );
      },
    );
  }

  /// Icono de Conversación / Miremos Juntos Switch (Hugeicons Conversation)
  static Widget conversation({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedConversation,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Apodo (Hugeicons Identification)
  static Widget identification({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedIdentification,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Código de Amigo (Hugeicons IdCard)
  static Widget idCard({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedIdCard,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Gestionar Amigos (Hugeicons AddTeam02)
  static Widget addTeam02({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedAddTeam02,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Test de Micrófono (Hugeicons AiMic)
  static Widget aiMic({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedAiMic,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Ajustes Generales (Reicon outline tuning3)
  static Widget generalSettings({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color;

        return SvgPicture.string(
          reiconSvg(Reicon.outline.tuning3),
          width: finalSize,
          height: finalSize,
          colorFilter: finalColor != null
              ? ColorFilter.mode(finalColor, BlendMode.srcIn)
              : null,
        );
      },
    );
  }

  /// Icono de Calibración / Overscan (Hugeicons SquareArrowExpand01)
  static Widget squareArrowExpand01({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedSquareArrowExpand01,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Modo Oscuro (Hugeicons Moon02)
  static Widget moon02({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedMoon02,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Paleta / Color de Acento (Hugeicons PaintBoard)
  static Widget paintBoard({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedPaintBoard,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Auto Acento / Destellos (Hugeicons Sparkles)
  static Widget sparkles({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedSparkles,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Acerca de (Reicon outline circleInfo)
  static Widget about({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color;

        return SvgPicture.string(
          reiconSvg(Reicon.outline.circleInfo),
          width: finalSize,
          height: finalSize,
          colorFilter: finalColor != null
              ? ColorFilter.mode(finalColor, BlendMode.srcIn)
              : null,
        );
      },
    );
  }

  /// Icono de TV Minimal / Canales cargados (Hugeicons TvMinimal)
  static Widget tvMinimal({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedTvMinimal,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }

  /// Icono de Descarga / Buscar actualizaciones (Hugeicons Download03)
  static Widget download03({double? size, Color? color}) {
    return Builder(
      builder: (context) {
        final iconTheme = IconTheme.of(context);
        final finalSize = size ?? iconTheme.size ?? 20.0;
        final finalColor = color ?? iconTheme.color ?? Colors.white;

        return HugeIcon(
          icon: HugeIcons.strokeRoundedDownload03,
          size: finalSize,
          color: finalColor,
        );
      },
    );
  }
}
