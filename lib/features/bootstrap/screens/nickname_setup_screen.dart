import 'package:flutter/material.dart';
import 'package:moai3/widgets/tv_common/moai_ambient_background.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/widgets/dialogs/tv_nickname_dialog.dart';

/// Pantalla obligatoria de configuración inicial de apodo (Onboarding / Primer inicio / Update).
/// Se asegura de que ningún dispositivo ingrese a la app sin identificarse.
class NicknameSetupScreen extends StatelessWidget {
  const NicknameSetupScreen({super.key});

  Future<void> _handleSave(BuildContext context, String newNickname) async {
    final trimmed = newNickname.trim();
    if (trimmed.isEmpty) return;

    final identity = context.read<DeviceIdentityService>();
    final watchParty = context.read<WatchPartyProvider>();

    try {
      await identity.saveNickname(trimmed);
    } catch (e) {
      debugPrint('[NicknameSetup] $e');
    }

    try {
      await watchParty.updateNickname(trimmed);
    } catch (e) {
      debugPrint('[NicknameSetup] $e');
    }

    if (context.mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: scheme.surface,
        // Mismo fondo ambiente que el resto de la app.
        body: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: MoaiAmbientBackground()),
            ),
            Center(
              child: SingleChildScrollView(
                child: TvNicknameDialog(
                  isMandatory: true,
                  onSaved: (name) => _handleSave(context, name),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
