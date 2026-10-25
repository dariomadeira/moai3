import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_ambient_background.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

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

  IconData _cornerIcon(Alignment alignment) {
    if (alignment == Alignment.topLeft) return MoaiIcons.northWest;
    if (alignment == Alignment.topRight) return MoaiIcons.northEast;
    if (alignment == Alignment.bottomLeft) return MoaiIcons.southWest;
    return MoaiIcons.southEast;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // Marco de calibración: solo el contorno en el acento; el fondo
    // ambiente se ve a través.
    final frameColor = scheme.primary.withValues(alpha: 0.55);

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
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: frameColor, width: 2),
                  ),
                  child: Stack(
                    children: [
                      for (final alignment in const [
                        Alignment.topLeft,
                        Alignment.topRight,
                        Alignment.bottomLeft,
                        Alignment.bottomRight,
                      ])
                        Align(
                          alignment: alignment,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              _cornerIcon(alignment),
                              color: scheme.primary,
                              size: MoaiIconSizes.lg,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    decoration: moaiDialogDecoration(scheme),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    MoaiIcons.screenCalibration,
                                    color: scheme.primary,
                                    size: MoaiIconSizes.xl,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          LocaleKeys.overlap_title.tr(),
                                          style: MoaiText.display(
                                            context,
                                            fontSize: 18,
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          LocaleKeys.overlap_subtitle.tr(),
                                          style: MoaiText.body(
                                            context,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: scheme.onSurface.withValues(
                                              alpha: 0.72,
                                            ),
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _PaddingAdjuster(
                                title: LocaleKeys.overlap_horizontal.tr(),
                                value: _tempX,
                                focusNode: _xFocus,
                                onChanged: (v) => setState(() => _tempX = v),
                                onFocusDown: _yFocus.requestFocus,
                              ),
                              const SizedBox(height: 10),
                              _PaddingAdjuster(
                                title: LocaleKeys.overlap_vertical.tr(),
                                value: _tempY,
                                focusNode: _yFocus,
                                onChanged: (v) => setState(() => _tempY = v),
                                onFocusUp: _xFocus.requestFocus,
                                onFocusDown: _buttonFocus.requestFocus,
                              ),
                              const SizedBox(height: 16),
                              TvFocusButton(
                                focusNode: _buttonFocus,
                                label: LocaleKeys.overlap_save.tr(),
                                onPressed: _save,
                                onArrowUp: _yFocus.requestFocus,
                              ),
                            ],
                          ),
                        ),
                      ],
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
}

class _PaddingAdjuster extends StatefulWidget {
  final String title;
  final double value;
  final FocusNode focusNode;
  final ValueChanged<double> onChanged;
  final VoidCallback? onFocusUp;
  final VoidCallback? onFocusDown;

  const _PaddingAdjuster({
    required this.title,
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
    final next = (widget.value + delta).clamp(0.0, 80.0);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final labelColor = scheme.onSurfaceVariant;
    final arrowColor = scheme.primary.withValues(alpha: _focused ? 1 : 0.6);

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft) {
          _nudge(-2);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          _nudge(2);
          return KeyEventResult.handled;
        }
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
        borderRadius: 16,
        elevated: false,
        solid: true,
        focused: _focused,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: MoaiText.body(
                      context,
                      color: labelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.value.round()} px',
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  MoaiIcons.arrowBack,
                  size: MoaiIconSizes.sm,
                  color: arrowColor,
                ),
                const SizedBox(width: 4),
                Icon(
                  MoaiIcons.arrowForward,
                  size: MoaiIconSizes.sm,
                  color: arrowColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
