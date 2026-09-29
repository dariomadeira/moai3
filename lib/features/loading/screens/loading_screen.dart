import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moai3/services/device_identity_service.dart';
import 'package:moai3/services/supabase_presence_service.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:provider/provider.dart';

/// Pantalla inicial de verificación de presencia y carga (SPEC-22 §4.1).
class LoadingScreen extends StatefulWidget {
  final DeviceIdentityService identityService;
  final SupabasePresenceService presenceService;

  const LoadingScreen({
    super.key,
    required this.identityService,
    required this.presenceService,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startVerification();
  }

  Future<void> _startVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final identity = await widget.identityService.getIdentity();
      final result = await widget.presenceService.verifyAndRegisterDevice(
        deviceId: identity.deviceId,
        appVersion: identity.appVersion,
      );

      if (!mounted) return;

      final record = result.record;
      if (!record.isActive) {
        // Dispositivo bloqueado (RB-04 / CASO-UC-02)
        context.go('/blocked', extra: record.blockReason);
      } else {
        // Dispositivo activo -> Ir a Home o Overlap si no está calibrado
        final tvSettings = context.read<TvSettingsProvider>();
        if (!tvSettings.hasOverlapConfig) {
          context.go('/overlap');
        } else {
          context.go('/home');
        }
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo conectar. Verifica tu conexión.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo conectar. Verifica tu conexión.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_isLoading) ...[
                CircularProgressIndicator(
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Conectando...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ] else ...[
                Icon(
                  Icons.wifi_off_rounded,
                  size: 56,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'No se pudo conectar.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  autofocus: true,
                  onPressed: _startVerification,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
