import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/movie_models.dart';
import 'package:moai3/services/titan_ranger_service.dart';

/// Lo que devuelve [TitanVodPreparer.prepare]: la URL del proxy local o, si
/// Ranger respondió algo que no se puede reproducir, un mensaje para la
/// persona. Las dos en null: Ranger no resolvió (se prueba otro camino).
typedef TitanPrepared = ({String? playUrl, String? error});

/// Prepara una película en Titan Ranger como la app oficial: SetEnv,
/// SetEntries y PrepareProgram con los datos de `getSlbInfo`. Ranger
/// responde la URL de su proxy local (`127.0.0.1/vod/0/<media>.m3u8`).
///
/// El programa queda con el nombre de la película ([MovieItem.contentId]):
/// el reproductor lo usa para saltar y para detenerlo al salir.
class TitanVodPreparer {
  const TitanVodPreparer._();

  /// Clave por defecto de la app oficial si no hay una configurada.
  static const _defaultPortalKey = '2b494e53756c664c2f44465245733572';

  static Future<TitanPrepared> prepare({
    required Map<String, dynamic> slbData,
    required MovieItem movie,
    required VodQualityOption quality,
    required VodMediaSource source,
    required String app,
    required String appVer,
    required String userId,
    required String devId,
    required String portalKey,
    required void Function(String) log,
  }) async {
    final cdnList = slbData['cdn_list'];
    if (cdnList is! List) return (playUrl: null, error: null);

    final entries = TitanRangerService.mapSlbEntries(cdnList);
    final readyEntries = entries
        .where(
          (e) =>
              (e['tag'] as String).isNotEmpty &&
              (e['sign_type'] as String).isNotEmpty,
        )
        .length;

    await TitanRangerService.init();

    // `android_id` real (Settings.System). El snField NO es el android_id.
    final androidId = await TitanRangerService.getAndroidId();
    final rawPlayParams = slbData['play_params'];
    final playParams = rawPlayParams is String
        ? rawPlayParams
        : (rawPlayParams == null ? '' : jsonEncode(rawPlayParams));

    log(
      '🛡️ [Titan Ranger] ${entries.length} entries ($readyEntries con link/sign_type), '
      'androidId=${androidId.isNotEmpty ? "OK" : "vacío"}, portalKey=${portalKey.isNotEmpty ? "OK" : "default"}',
    );

    await TitanRangerService.setEnv(
      app: app.isNotEmpty ? app : 'com.android.msandroid',
      appVer: appVer.isNotEmpty ? appVer : '50503',
      userId: userId,
      devId: devId.isNotEmpty ? devId : '02:00:00:00:00:00',
      communicationKey: portalKey.isNotEmpty ? portalKey : _defaultPortalKey,
      params: playParams,
      androidId: androidId,
    );

    await TitanRangerService.setEntries(entries);
    // Deja que Ranger procese SetEntries antes de iniciar PrepareProgram.
    // La app oficial encola ambas llamadas en el mismo handler nativo.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final programPayload = {
      'name': movie.contentId,
      'buss': 'vod',
      'title': movie.name,
      'episode': '1',
      'from': 'detail',
      'cause': 'user',
      'media': source.mediaContentId,
      'medias': [
        {
          'name': source.mediaContentId,
          'license': source.license ?? '',
          'lang': source.audioInfo,
          'quality': quality.quality,
          'vcodec': source.encodeFormat ?? 'h265',
          'format': source.videoFormat ?? source.videoType ?? 'ts',
        },
      ],
      'start': 0,
    };

    log(
      '🛡️ [Titan Ranger] Despachando PrepareProgram para: "${movie.name}"...',
    );
    final statusResult = await TitanRangerService.prepareProgram(
      // La app oficial pasa program.getName() (ID del programa) como
      // "name" y program.getBuss() ("vod") como "extra".
      name: movie.contentId,
      program: programPayload,
      extra: 'vod',
    );

    final playUrl = statusResult?['play_url']?.toString().trim() ?? '';
    if (playUrl.isEmpty) {
      log('⚠️ [Titan Ranger] No se obtuvo play_url nativo de Ranger');
      return (playUrl: null, error: null);
    }
    if (playUrl.startsWith('mem://') || playUrl.startsWith('ijkhttphook:')) {
      // Ranger resolvió, pero ese esquema requiere el proxy/datasource
      // nativo de IJK (servidor /playinfo + titan_port), no ExoPlayer.
      log(
        '⚠️ [Titan Ranger] play_url con esquema no reproducible por ExoPlayer: $playUrl',
      );
      return (
        playUrl: null,
        error: LocaleKeys.movies_error_internal_stream.tr(
          namedArgs: {'scheme': playUrl.split(':').first},
        ),
      );
    }
    log('🎉 [Titan Ranger] Stream URL resuelta por libranger-jni: $playUrl');
    return (playUrl: playUrl, error: null);
  }
}
