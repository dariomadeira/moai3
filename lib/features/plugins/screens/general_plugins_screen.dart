import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:moai3/services/arcade_plugin_service.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';

/// Pantalla de gestión de Plugins Generales para Android TV (idéntica a la estructura de SourcesScreen).
class GeneralPluginsScreen extends StatefulWidget {
  const GeneralPluginsScreen({super.key});

  @override
  State<GeneralPluginsScreen> createState() => _GeneralPluginsScreenState();
}

class _GeneralPluginsScreenState extends State<GeneralPluginsScreen> {
  final ArcadePluginService _arcadePlugin = ArcadePluginService.instance;
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'general_plugins_back');
  final FocusNode _emptyFocusNode = FocusNode(debugLabel: 'general_plugins_empty');

  // Focus nodes para plugin instalado (update & remove)
  final FocusNode _installedUpdateFocus = FocusNode(debugLabel: 'arcade_update_focus');
  final FocusNode _installedRemoveFocus = FocusNode(debugLabel: 'arcade_remove_focus');

  // Focus node para plugin disponible en catálogo
  final FocusNode _availableFocusNode = FocusNode(debugLabel: 'arcade_available_focus');

  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _arcadePlugin.addListener(_onPluginUpdated);
    _arcadePlugin.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_arcadePlugin.isInstalled) {
          _installedRemoveFocus.requestFocus();
        } else {
          _availableFocusNode.requestFocus();
        }
      }
    });
  }

  void _onPluginUpdated() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _arcadePlugin.removeListener(_onPluginUpdated);
    _backFocusNode.dispose();
    _emptyFocusNode.dispose();
    _installedUpdateFocus.dispose();
    _installedRemoveFocus.dispose();
    _availableFocusNode.dispose();
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    super.dispose();
  }

  Future<void> _uninstallArcade() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'plugins_arcade_uninstall_dialog_title'.tr(),
            style: MoaiText.display(ctx, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'plugins_arcade_uninstall_dialog_desc'.tr(),
            style: MoaiText.body(ctx),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common_cancel'.tr(), style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: scheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('plugins_uninstall_tooltip'.tr()),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _arcadePlugin.uninstallPlugin();
      if (mounted) _availableFocusNode.requestFocus();
    }
  }

  Future<void> _installArcade() async {
    if (_arcadePlugin.isDownloading || _arcadePlugin.isInstalled) return;
    await _arcadePlugin.installPlugin();
    if (mounted && _arcadePlugin.isInstalled) {
      _installedRemoveFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isInstalled = _arcadePlugin.isInstalled;
    final totalInstalledCount = isInstalled ? 1 : 0;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context, scheme, totalInstalledCount),
                const SizedBox(height: 20),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Columna Izquierda: Plugins Instalados
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                'plugins_installed_column_title'.tr(),
                                style: MoaiText.body(
                                  context,
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: !isInstalled
                                  ? TvEmptyStateCard(
                                      focusNode: _emptyFocusNode,
                                      icon: AppIcons.plugin,
                                      message: 'plugins_empty_installed_msg'.tr(),
                                      onFocusUp: () => _backFocusNode.requestFocus(),
                                      onFocusRight: () => _availableFocusNode.requestFocus(),
                                    )
                                  : SingleChildScrollView(
                                      controller: _leftScrollController,
                                      child: _InstalledPluginTile(
                                        title: 'plugins_arcade_name'.tr(),
                                        subtitle: 'plugins_arcade_desc'.tr(
                                          namedArgs: {'abi': ArcadePluginService.getDeviceAbi()},
                                        ),
                                        updateFocus: _installedUpdateFocus,
                                        removeFocus: _installedRemoveFocus,
                                        onUpdate: _installArcade,
                                        onRemove: _uninstallArcade,
                                        onUpdateKeyUp: () => _backFocusNode.requestFocus(),
                                        onRemoveKeyUp: () => _backFocusNode.requestFocus(),
                                        onRemoveKeyRight: () => _availableFocusNode.requestFocus(),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Columna Derecha: Plugins Disponibles (Recomendados)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                'plugins_available_column_title'.tr(),
                                style: MoaiText.body(
                                  context,
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _rightScrollController,
                                child: _AvailablePluginTile(
                                  title: 'plugins_arcade_available_name'.tr(),
                                  packageName: 'plugins_arcade_available_desc'.tr(),
                                  focusNode: _availableFocusNode,
                                  isInstalled: isInstalled,
                                  isDownloading: _arcadePlugin.isDownloading,
                                  downloadProgress: _arcadePlugin.downloadProgress,
                                  statusMessage: _arcadePlugin.statusMessage,
                                  onInstall: _installArcade,
                                  onKeyLeft: () {
                                    if (isInstalled) {
                                      _installedRemoveFocus.requestFocus();
                                    } else {
                                      _emptyFocusNode.requestFocus();
                                    }
                                  },
                                  onKeyUp: () => _backFocusNode.requestFocus(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ColorScheme scheme, int totalPlugins) {
    final countText = totalPlugins == 1
        ? 'plugins_count_single'.tr(namedArgs: {'count': '1'})
        : 'plugins_count_plural'.tr(namedArgs: {'count': '$totalPlugins'});

    return Row(
      children: [
        _BackButton(
          focusNode: _backFocusNode,
          onPressed: () => Navigator.of(context).pop(),
          onFocusRight: () => _arcadePlugin.isInstalled
              ? _installedRemoveFocus.requestFocus()
              : _availableFocusNode.requestFocus(),
          onFocusDown: () => _arcadePlugin.isInstalled
              ? _installedRemoveFocus.requestFocus()
              : _availableFocusNode.requestFocus(),
        ),
        const SizedBox(width: 14),
        Material(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: AppIcon(
              icon: AppIcons.plugin,
              color: scheme.onPrimaryContainer,
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'plugins_admin_title'.tr(),
                style: MoaiText.display(
                  context,
                  color: scheme.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'plugins_admin_subtitle'.tr(),
                style: MoaiText.body(
                  context,
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              countText,
              style: MoaiText.body(
                context,
                color: scheme.onTertiaryContainer,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final VoidCallback? onFocusRight;
  final VoidCallback? onFocusDown;

  const _BackButton({
    required this.focusNode,
    required this.onPressed,
    this.onFocusRight,
    this.onFocusDown,
  });

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final bg = _isFocused ? scheme.primary : scheme.surfaceContainerLow;
    final fg = _isFocused ? scheme.onPrimary : scheme.onSurface;

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowRight && widget.onFocusRight != null) {
          widget.onFocusRight!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && widget.onFocusDown != null) {
          widget.onFocusDown!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.gameButtonA) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _isFocused ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 52,
              height: 52,
              child: AppIcon(
                icon: AppIcons.arrowLeft,
                color: fg,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InstalledPluginTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final FocusNode updateFocus;
  final FocusNode removeFocus;
  final VoidCallback onUpdate;
  final VoidCallback onRemove;
  final VoidCallback onUpdateKeyUp;
  final VoidCallback onRemoveKeyUp;
  final VoidCallback? onRemoveKeyRight;

  const _InstalledPluginTile({
    required this.title,
    required this.subtitle,
    required this.updateFocus,
    required this.removeFocus,
    required this.onUpdate,
    required this.onRemove,
    required this.onUpdateKeyUp,
    required this.onRemoveKeyUp,
    this.onRemoveKeyRight,
  });

  @override
  State<_InstalledPluginTile> createState() => _InstalledPluginTileState();
}

class _InstalledPluginTileState extends State<_InstalledPluginTile> {
  @override
  void initState() {
    super.initState();
    widget.updateFocus.addListener(_onFocus);
    widget.removeFocus.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.updateFocus.removeListener(_onFocus);
    widget.removeFocus.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isFocused = widget.updateFocus.hasFocus || widget.removeFocus.hasFocus;

    final bg = isFocused ? scheme.primary : scheme.surfaceContainerLow;
    final titleColor = isFocused ? scheme.onPrimary : scheme.onSurface;
    final descColor = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    final iconBg = isFocused
        ? scheme.onPrimary.withValues(alpha: 0.18)
        : scheme.primaryContainer;
    final iconColor = isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Material(
              color: iconBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: AppIcon(
                  icon: AppIcons.plugin,
                  size: 22,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MoaiText.body(
                      context,
                      color: titleColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MoaiText.body(
                      context,
                      color: descColor,
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _IconButtonAction(
              focusNode: widget.updateFocus,
              tooltip: 'plugins_reinstall_tooltip'.tr(),
              icon: AppIcons.update,
              onPressed: widget.onUpdate,
              parentFocused: isFocused,
              onKeyRight: () => widget.removeFocus.requestFocus(),
              onKeyUp: widget.onUpdateKeyUp,
            ),
            const SizedBox(width: 8),
            _IconButtonAction(
              focusNode: widget.removeFocus,
              tooltip: 'plugins_uninstall_tooltip'.tr(),
              icon: AppIcons.delete,
              onPressed: widget.onRemove,
              parentFocused: isFocused,
              onKeyLeft: () => widget.updateFocus.requestFocus(),
              onKeyRight: widget.onRemoveKeyRight,
              onKeyUp: widget.onRemoveKeyUp,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailablePluginTile extends StatefulWidget {
  final String title;
  final String packageName;
  final FocusNode focusNode;
  final bool isInstalled;
  final bool isDownloading;
  final double downloadProgress;
  final String statusMessage;
  final VoidCallback onInstall;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyUp;

  const _AvailablePluginTile({
    required this.title,
    required this.packageName,
    required this.focusNode,
    required this.isInstalled,
    required this.isDownloading,
    required this.downloadProgress,
    required this.statusMessage,
    required this.onInstall,
    required this.onKeyLeft,
    required this.onKeyUp,
  });

  @override
  State<_AvailablePluginTile> createState() => _AvailablePluginTileState();
}

class _AvailablePluginTileState extends State<_AvailablePluginTile> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) {
      setState(() => _isFocused = widget.focusNode.hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final bg = _isFocused ? scheme.primary : scheme.surfaceContainerLow;
    final titleColor = _isFocused ? scheme.onPrimary : scheme.onSurface;
    final descColor = _isFocused
        ? scheme.onPrimary.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    final iconBg = _isFocused
        ? scheme.onPrimary.withValues(alpha: 0.18)
        : scheme.primaryContainer;
    final iconColor = _isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Focus(
        focusNode: widget.focusNode,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft) {
            widget.onKeyLeft();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp) {
            widget.onKeyUp();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space ||
              key == LogicalKeyboardKey.gameButtonA) {
            widget.onInstall();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: InkWell(
            onTap: widget.onInstall,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Material(
                      color: iconBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: AppIcon(
                          icon: AppIcons.plugin,
                          size: 22,
                          color: iconColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MoaiText.body(
                              context,
                              color: titleColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.packageName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MoaiText.body(
                              context,
                              color: descColor,
                              fontSize: 12,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: widget.isDownloading
                          ? (_isFocused
                              ? scheme.onPrimary.withValues(alpha: 0.2)
                              : scheme.primaryContainer)
                          : widget.isInstalled
                              ? (_isFocused
                                  ? scheme.onPrimary.withValues(alpha: 0.2)
                                  : scheme.tertiaryContainer)
                              : (_isFocused
                                  ? scheme.onPrimary
                                  : scheme.primary),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.isDownloading) ...[
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _isFocused
                                      ? scheme.onPrimary
                                      : scheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${(widget.downloadProgress * 100).toStringAsFixed(0)}%',
                                style: MoaiText.body(
                                  context,
                                  color: _isFocused
                                      ? scheme.onPrimary
                                      : scheme.onPrimaryContainer,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ] else if (widget.isInstalled) ...[
                              AppIcon(
                                icon: AppIcons.check,
                                size: 16,
                                color: _isFocused
                                    ? scheme.onPrimary
                                    : scheme.onTertiaryContainer,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'plugins_status_installed'.tr(),
                                style: MoaiText.body(
                                  context,
                                  color: _isFocused
                                      ? scheme.onPrimary
                                      : scheme.onTertiaryContainer,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ] else ...[
                              AppIcon(
                                icon: AppIcons.download,
                                size: 16,
                                color: _isFocused
                                    ? scheme.primary
                                    : scheme.onPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'plugins_action_install'.tr(),
                                style: MoaiText.body(
                                  context,
                                  color: _isFocused
                                      ? scheme.primary
                                      : scheme.onPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButtonAction extends StatefulWidget {
  final FocusNode focusNode;
  final String tooltip;
  final dynamic icon;
  final VoidCallback onPressed;
  final bool parentFocused;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;

  const _IconButtonAction({
    required this.focusNode,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.parentFocused,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
  });

  @override
  State<_IconButtonAction> createState() => _IconButtonActionState();
}

class _IconButtonActionState extends State<_IconButtonAction> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final bg = _isFocused
        ? (widget.parentFocused ? scheme.onPrimary : scheme.primary)
        : (widget.parentFocused
            ? scheme.onPrimary.withValues(alpha: 0.2)
            : scheme.surfaceContainerHighest);

    final iconColor = _isFocused
        ? (widget.parentFocused ? scheme.primary : scheme.onPrimary)
        : (widget.parentFocused
            ? scheme.onPrimary
            : scheme.onSurfaceVariant);

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft && widget.onKeyLeft != null) {
          widget.onKeyLeft!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight && widget.onKeyRight != null) {
          widget.onKeyRight!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp && widget.onKeyUp != null) {
          widget.onKeyUp!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.gameButtonA) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedScale(
        scale: _isFocused ? 1.1 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Tooltip(
          message: widget.tooltip,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 40,
                height: 40,
                child: widget.icon is List<List<dynamic>>
                    ? AppIcon(
                        icon: widget.icon as List<List<dynamic>>,
                        size: 20,
                        color: iconColor,
                      )
                    : Icon(
                        widget.icon as IconData,
                        size: 20,
                        color: iconColor,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
