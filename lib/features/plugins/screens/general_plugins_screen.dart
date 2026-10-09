import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/services/arcade_plugin_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';

/// Pantalla de gestión de Plugins Generales para Android TV (idéntica a la estructura de SourcesScreen).
class GeneralPluginsScreen extends StatefulWidget {
  const GeneralPluginsScreen({super.key});

  @override
  State<GeneralPluginsScreen> createState() => _GeneralPluginsScreenState();
}

class _GeneralPluginsScreenState extends State<GeneralPluginsScreen> {
  final ArcadePluginService _arcadePlugin = ArcadePluginService.instance;
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'general_plugins_back');
  final FocusNode _arcadeActionFocusNode = FocusNode(debugLabel: 'arcade_plugin_action');

  @override
  void initState() {
    super.initState();
    _arcadePlugin.addListener(_onPluginUpdated);
    _arcadePlugin.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _arcadeActionFocusNode.requestFocus();
    });
  }

  void _onPluginUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _arcadePlugin.removeListener(_onPluginUpdated);
    _backFocusNode.dispose();
    _arcadeActionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleArcadeAction() async {
    if (_arcadePlugin.isDownloading) return;

    if (_arcadePlugin.isInstalled) {
      // Confirmar desinstalación
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final scheme = Theme.of(ctx).colorScheme;
          return AlertDialog(
            backgroundColor: scheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Desinstalar Plugin Arcade',
              style: MoaiText.display(ctx, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            content: Text(
              '¿Deseas eliminar el motor Arcade FBNeo? Esta acción liberará ~69 MB de espacio y desactivará la sección Arcade del menú lateral.',
              style: MoaiText.body(ctx),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancelar', style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: scheme.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Desinstalar'),
              ),
            ],
          );
        },
      );

      if (confirm == true) {
        await _arcadePlugin.uninstallPlugin();
      }
    } else {
      // Instalar plugin
      await _arcadePlugin.installPlugin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isInstalled = _arcadePlugin.isInstalled;
    final isDownloading = _arcadePlugin.isDownloading;
    final progress = _arcadePlugin.downloadProgress;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Encabezado con Botón Volver
              Row(
                children: [
                  TvFocusButton(
                    focusNode: _backFocusNode,
                    label: 'Volver',
                    icon: Symbols.arrow_back,
                    variant: TvButtonVariant.surface,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plugins Generales',
                        style: MoaiText.display(
                          context,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Módulos y motores de extensión nativos del sistema',
                        style: MoaiText.body(
                          context,
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. Lista de Plugins Disponibles (Tarjeta de Plugin Arcade)
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isInstalled
                                    ? scheme.primaryContainer
                                    : scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Symbols.sports_esports,
                                size: 36,
                                color: isInstalled
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Moai Arcade Engine (FBNeo)',
                                        style: MoaiText.display(
                                          context,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isInstalled
                                              ? Colors.green.withValues(alpha: 0.2)
                                              : scheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isInstalled
                                                ? Colors.green
                                                : scheme.outline,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          isInstalled ? 'Instalado (~69 MB)' : 'No Instalado',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isInstalled
                                                ? Colors.greenAccent
                                                : scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Motor de emulación retro nativo de alta precisión para Capcom CPS-1/2/3, NeoGeo y Arcade. Activa la sección Juegos en el menú principal.',
                                    style: MoaiText.body(
                                      context,
                                      fontSize: 13,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Arquitectura detectada: ${ArcadePluginService.getDeviceAbi()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Botón de Acción D-pad M3
                            TvFocusButton(
                              focusNode: _arcadeActionFocusNode,
                              label: isDownloading
                                  ? 'Descargando...'
                                  : isInstalled
                                      ? 'Desinstalar'
                                      : 'Instalar Plugin',
                              icon: isDownloading
                                  ? Symbols.downloading
                                  : isInstalled
                                      ? Symbols.delete
                                      : Symbols.download,
                              variant: isInstalled
                                  ? TvButtonVariant.destructive
                                  : TvButtonVariant.secondary,
                              loading: isDownloading,
                              onPressed: _handleArcadeAction,
                            ),
                          ],
                        ),

                        // Barra de progreso de descarga si está en proceso
                        if (isDownloading) ...[
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: progress > 0 ? progress : null,
                            backgroundColor: scheme.surfaceContainerHighest,
                            color: scheme.primary,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _arcadePlugin.statusMessage,
                                style: MoaiText.body(
                                  context,
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
