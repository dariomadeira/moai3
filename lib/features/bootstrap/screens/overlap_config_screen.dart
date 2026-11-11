import 'package:moai3/features/home/widgets/home_clock.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_ambient_background.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Margen máximo de calibración, en px por lado.
const double _kMaxMargin = 80;

/// Paso de cada toque de ◀ ▶.
const double _kStep = 2;

class OverlapConfigScreen extends StatefulWidget {
  /// Primera vez (bootstrap) → al guardar va a home.
  /// Desde Ajustes (`false`) → pop al guardar / Back.
  final bool isFirstRun;

  const OverlapConfigScreen({super.key, this.isFirstRun = true});

  @override
  State<OverlapConfigScreen> createState() => _OverlapConfigScreenState();
}

class _OverlapConfigScreenState extends State<OverlapConfigScreen> {
  double _tempX = 20;
  double _tempY = 20;

  final FocusNode _xFocus = FocusNode(debugLabel: 'overscan_x');
  final FocusNode _yFocus = FocusNode(debugLabel: 'overscan_y');
  final FocusNode _buttonFocus = FocusNode(debugLabel: 'overscan_save');

  @override
  void initState() {
    super.initState();
    final tvSettings = context.read<TvSettingsProvider>();
    _tempX = tvSettings.overlapPaddingX;
    _tempY = tvSettings.overlapPaddingY;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _xFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _xFocus.dispose();
    _yFocus.dispose();
    _buttonFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.read<TvSettingsProvider>().setOverlapConfig(
      x: _tempX,
      y: _tempY,
    );
    if (!mounted) return;
    if (widget.isFirstRun) {
      final wp = context.read<WatchPartyProvider>();
      final nick = wp.nickname;
      if (nick == null || nick.trim().isEmpty) {
        context.go('/nickname_setup');
      } else {
        context.go('/home');
      }
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return PopScope(
      canPop: !widget.isFirstRun,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: MoaiAmbientBackground()),
            Positioned.fill(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                  horizontal: _tempX,
                  vertical: _tempY,
                ),
                // El panel esmerilado ES el marco: sus bordes son los que
                // se calibran y el contenido va adentro, sin otro panel.
                child: _CalibrationFrame(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _content(scheme),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado como el de los diálogos: ícono en el acento y título con
          // el degradado de los paneles.
          Row(
            children: [
              Icon(
                MoaiIcons.screenCalibration,
                color: Theme.of(context).colorScheme.primary,
                size: MoaiIconSizes.xl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: HomeClock.timeShader,
                        child: Text(
                          LocaleKeys.overlap_title.tr(),
                          style: MoaiText.display(
                            context,
                            fontSize: 18,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      LocaleKeys.overlap_subtitle.tr(),
                      style: MoaiText.body(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PaddingAdjuster(
                icon: MoaiIcons.overscanHorizontal,
                title: LocaleKeys.overlap_horizontal.tr(),
                hint: LocaleKeys.overlap_horizontal_hint.tr(),
                value: _tempX,
                focusNode: _xFocus,
                onChanged: (v) => setState(() => _tempX = v),
                onFocusDown: _yFocus.requestFocus,
              ),
              const SizedBox(height: 10),
              _PaddingAdjuster(
                icon: MoaiIcons.overscanVertical,
                title: LocaleKeys.overlap_vertical.tr(),
                hint: LocaleKeys.overlap_vertical_hint.tr(),
                value: _tempY,
                focusNode: _yFocus,
                onChanged: (v) => setState(() => _tempY = v),
                onFocusUp: _xFocus.requestFocus,
                onFocusDown: _buttonFocus.requestFocus,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    MoaiIcons.remote,
                    size: MoaiIconSizes.xs,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    LocaleKeys.overlap_hint.tr(),
                    style: MoaiText.body(
                      context,
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TvDialogButton(
              focusNode: _buttonFocus,
              label: LocaleKeys.overlap_save.tr(),
              icon: MoaiIcons.check,
              variant: TvDialogButtonVariant.primary,
              onPressed: _save,
              onKeyUp: _yFocus.requestFocus,
            ),
          ),
        ],
      ),
    );
  }
}

/// Marco de calibración: el vidrio esmerilado de los paneles grandes (fondo
/// desenfocado, velo blanco, filo de luz y sombra) ocupando el área
/// calibrada y, en cada esquina, una etiqueta de cristal con la flecha.
class _CalibrationFrame extends StatelessWidget {
  final Widget child;

  const _CalibrationFrame({required this.child});

  static const _corners = [
    (Alignment.topLeft, MoaiIcons.northWest),
    (Alignment.topRight, MoaiIcons.northEast),
    (Alignment.bottomLeft, MoaiIcons.southWest),
    (Alignment.bottomRight, MoaiIcons.southEast),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return MoaiGlass(
      frosted: true,
      borderRadius: MoaiGlass.panelRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          for (final (alignment, icon) in _corners)
            Align(
              alignment: alignment,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: moaiGlassTagDecoration(scheme, radius: 999),
                  child: Icon(
                    icon,
                    color: scheme.primary,
                    size: MoaiIconSizes.md,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaddingAdjuster extends StatefulWidget {
  final IconData icon;
  final String title;
  final String hint;
  final double value;
  final FocusNode focusNode;
  final ValueChanged<double> onChanged;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;

  const _PaddingAdjuster({
    required this.icon,
    required this.title,
    required this.hint,
    required this.value,
    required this.focusNode,
    required this.onChanged,
    this.onFocusUp,
    this.onFocusDown,
  });

  @override
  State<_PaddingAdjuster> createState() => _PaddingAdjusterState();
}

class _PaddingAdjusterState extends State<_PaddingAdjuster> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  void _nudge(double delta) {
    final next = (widget.value + delta).clamp(0.0, _kMaxMargin);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        // Mantener ◀ ▶ apretado también ajusta (KeyRepeatEvent).
        if (event is KeyUpEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft) {
          _nudge(-_kStep);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          _nudge(_kStep);
          return KeyEventResult.handled;
        }
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (key == LogicalKeyboardKey.arrowUp && widget.onFocusUp != null) {
          widget.onFocusUp!();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && widget.onFocusDown != null) {
          widget.onFocusDown!();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      // Ficha de cristal como TvTile: el foco es el borde del acento.
      child: MoaiGlass(
        borderRadius: MoaiGlass.panelRadius,
        elevated: false,
        solid: true,
        focused: _focused,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: moaiGlassTagDecoration(scheme, radius: 12),
                  child: Icon(
                    widget.icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: MoaiIconSizes.md,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: MoaiText.body(
                          context,
                          color: scheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.hint,
                        style: MoaiText.body(
                          context,
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _StepButton(
                  icon: MoaiIcons.chevronLeft,
                  active: _focused,
                  onTap: () => _nudge(-_kStep),
                ),
                SizedBox(
                  width: 84,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${widget.value.round()}'),
                        TextSpan(
                          text: ' px',
                          style: MoaiText.body(
                            context,
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: MoaiText.display(context, color: scheme.onSurface)
                        .copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
                _StepButton(
                  icon: MoaiIcons.chevronRight,
                  active: _focused,
                  onTap: () => _nudge(_kStep),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MarginBar(fraction: widget.value / _kMaxMargin),
          ],
        ),
      ),
    );
  }
}

/// Botón redondo ◀ / ▶: cristal blanco en reposo; con la ficha enfocada, el
/// acento con brillo y halo (avisa que las flechas ajustan).
class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 34,
        height: 34,
        decoration: moaiGlassButtonDecoration(scheme, focused: active),
        child: Icon(
          icon,
          size: MoaiIconSizes.sm,
          color: active ? scheme.onPrimary : scheme.primary,
        ),
      ),
    );
  }
}

/// Barra fina con el margen actual sobre el máximo.
class _MarginBar extends StatelessWidget {
  final double fraction;

  const _MarginBar({required this.fraction});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 4,
        color: scheme.onSurface.withValues(alpha: 0.08),
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          widthFactor: fraction.clamp(0.0, 1.0),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(scheme.primary, Colors.white, 0.35)!,
                  scheme.primary,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
