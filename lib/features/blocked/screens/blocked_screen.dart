import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pantalla de bloqueo para dispositivos deshabilitados (SPEC-22 §4.2).
class BlockedScreen extends StatelessWidget {
  final String? blockReason;

  const BlockedScreen({
    super.key,
    this.blockReason,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasReason = blockReason != null && blockReason!.trim().isNotEmpty;
    final message = hasReason
        ? blockReason!.trim()
        : 'Este dispositivo ha sido deshabilitado. Contacta al administrador para más información.';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.block,
                    size: 64,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Dispositivo Bloqueado',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    autofocus: true,
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
