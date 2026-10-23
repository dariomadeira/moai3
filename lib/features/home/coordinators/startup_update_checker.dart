import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:moai3/services/plugin_host_service.dart';
import 'package:moai3/services/plugin_update_service.dart';
import 'package:moai3/services/update_service.dart';
import 'package:moai3/widgets/dialogs/plugin_update_dialog.dart';
import 'package:moai3/widgets/dialogs/update_dialog.dart';
import 'package:provider/provider.dart';

/// Chequeo de actualizaciones al entrar al home (SPEC-31): primero el APK y,
/// solo si está al día, los plugins.
abstract final class StartupUpdateChecker {
  /// Espera para que la interfaz y los canales carguen antes de consultar.
  static const delay = Duration(seconds: 4);

  static Future<void> run(BuildContext context) async {
    await Future<void>.delayed(delay);
    if (!context.mounted) return;

    final appUpdate = await UpdateService.checkForUpdate();
    if (!context.mounted) return;
    if (appUpdate != null) {
      // Si el usuario actualiza, la app se reinstala: no tiene sentido seguir.
      unawaited(UpdateDialog.show(context, appUpdate));
      return;
    }

    try {
      final pluginHost = context.read<PluginHostController>();
      if (pluginHost.sources.isEmpty) return;
      final pendingUpdates = await PluginUpdateService.checkForUpdates(
        pluginHost.sources,
      );
      if (pendingUpdates.isNotEmpty && context.mounted) {
        unawaited(PluginUpdateDialog.show(context, pendingUpdates));
      }
    } catch (e) {
      debugPrint('[StartupUpdateChecker] Error comprobando plugins: $e');
    }
  }
}
