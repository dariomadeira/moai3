import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/theme/app_icons.dart';
import 'package:provider/provider.dart';
import 'package:moai3/services/watch_party_voice_coordinator.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';

/// Componente de la barra superior en Modo TV para la funcionalidad "Mirar juntos".
///
/// Muestra dinámicamente:
/// 1. Área Audio Entrante ("Carlos TV hablando..."): Idéntica en colores y estilos al Overlay (scheme.primary y scheme.onPrimary).
/// 2. Área Micrófono: Enfocable por D-Pad con respuestas completas de navegación.
class TvWatchPartyHeaderBar extends StatefulWidget {
  /// Modo Desarrollador / Testeo: Forzar visibilidad y simulaciones para pruebas visuales en TV
  static bool debugForceVisible = false;
  static bool debugSimulateIncomingAudio = false;
  static bool debugSimulateRecording = false;

  final FocusNode? micFocusNode;
  final VoidCallback? onLongPressMic;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const TvWatchPartyHeaderBar({
    super.key,
    this.micFocusNode,
    this.onLongPressMic,
    this.onKeyLeft,
    this.onKeyUp,
    this.onKeyDown,
  });

  /// Método auxiliar para activar fácilmente el modo de testeo desde cualquier pantalla/diálogo de prueba.
  static void setDebugMode({
    bool forceVisible = true,
    bool simulateIncomingAudio = false,
    bool simulateRecording = false,
    int mockFriendsCount = 2,
  }) {
    debugForceVisible = forceVisible;
    debugSimulateIncomingAudio = simulateIncomingAudio;
    debugSimulateRecording = simulateRecording;
  }

  @override
  State<TvWatchPartyHeaderBar> createState() => _TvWatchPartyHeaderBarState();
}

class _TvWatchPartyHeaderBarState extends State<TvWatchPartyHeaderBar> {
  late final FocusNode _micFocusNode;
  bool _isMicFocused = false;
  bool _isKeyDown = false;
  bool _longPressTriggered = false;
  Timer? _longPressTimer;

  @override
  void initState() {
    super.initState();
    _micFocusNode = widget.micFocusNode ?? FocusNode(debugLabel: 'TvWatchPartyHeaderMic');
    _micFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _micFocusNode.removeListener(_onFocusChange);
    if (widget.micFocusNode == null) {
      _micFocusNode.dispose();
    }
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isMicFocused = _micFocusNode.hasFocus;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDevMode = TvWatchPartyHeaderBar.debugForceVisible;
    final watchPartyProvider = context.watch<WatchPartyProvider?>();
    final coordinator = context.watch<WatchPartyVoiceCoordinator?>();

    final enabled = isDevMode || (watchPartyProvider?.enabled ?? false);
    if (!enabled) {
      return const SizedBox.shrink();
    }

    final hasFriendsInChannel = isDevMode || (watchPartyProvider?.hasFriendsInSameChannel ?? false);
    final isRecording = TvWatchPartyHeaderBar.debugSimulateRecording || (coordinator?.isRecording ?? false);
    final isPlaying = TvWatchPartyHeaderBar.debugSimulateIncomingAudio || (coordinator?.isPlaying ?? false);
    final speakerName = (TvWatchPartyHeaderBar.debugSimulateIncomingAudio ? 'Carlos TV' : null) ?? coordinator?.currentSpeakerName;

    final showYellowMic = hasFriendsInChannel;

    if (!showYellowMic && !isPlaying) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12, right: 4),
      child: SizedBox(
        height: 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Audio Entrante ("Carlos TV hablando...")
            if (isPlaying) ...[
              ExcludeFocus(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(18),
                      // boxShadow: [
                      //   BoxShadow(
                      //     color: Colors.black.withValues(alpha: 0.08),
                      //     blurRadius: 20,
                      //     offset: const Offset(0, 6),
                      //   ),
                      //   BoxShadow(
                      //     color: Colors.black.withValues(alpha: 0.12),
                      //     blurRadius: 6,
                      //     offset: const Offset(0, 2),
                      //   ),
                      // ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          icon: AppIcons.voiceTest,
                          color: scheme.onPrimary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              speakerName != null
                                  ? 'watch_party_friend_speaking'.tr(namedArgs: {'name': speakerName})
                                  : 'Escuchando audio...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MoaiText.body(
                                context,
                                color: scheme.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // 2. Botón de Micrófono (Enfocable por D-Pad)
            if (showYellowMic)
              _buildMicPill(
                context,
                coordinator,
                isRecording,
                scheme,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicPill(
    BuildContext context,
    WatchPartyVoiceCoordinator? coordinator,
    bool isRecording,
    ColorScheme scheme,
  ) {
    final recordingSecs = coordinator?.recordingSeconds ?? 0;
    final remainingSeconds = (30 - recordingSecs).clamp(0, 30);

    final backgroundColor = isRecording
        ? scheme.error
        : (_isMicFocused ? scheme.primary : scheme.surfaceContainerHighest);

    final foregroundColor = isRecording
        ? scheme.onError
        : (_isMicFocused ? scheme.onPrimary : scheme.onSurfaceVariant);

    return Focus(
      focusNode: _micFocusNode,
      onKeyEvent: (node, event) {
        final key = event.logicalKey;
        if (event is KeyDownEvent) {
          if (key == LogicalKeyboardKey.arrowLeft) {
            if (widget.onKeyLeft != null) {
              widget.onKeyLeft?.call();
              return KeyEventResult.handled;
            }
          } else if (key == LogicalKeyboardKey.arrowUp) {
            if (widget.onKeyUp != null) {
              widget.onKeyUp?.call();
              return KeyEventResult.handled;
            }
          } else if (key == LogicalKeyboardKey.arrowDown) {
            if (widget.onKeyDown != null) {
              widget.onKeyDown?.call();
              return KeyEventResult.handled;
            }
          }
        }

        final isActionButton = key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.gameButtonA ||
            key == LogicalKeyboardKey.space;

        if (isActionButton) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            if (event is KeyDownEvent && !_isKeyDown) {
              _isKeyDown = true;
              _longPressTriggered = false;
              _longPressTimer?.cancel();
              if (!isRecording && widget.onLongPressMic != null) {
                _longPressTimer = Timer(const Duration(milliseconds: 600), () {
                  _longPressTriggered = true;
                  widget.onLongPressMic?.call();
                });
              }
            }
            return KeyEventResult.handled;
          } else if (event is KeyUpEvent) {
            if (_isKeyDown) {
              _isKeyDown = false;
              _longPressTimer?.cancel();
              _longPressTimer = null;
              if (!_longPressTriggered) {
                coordinator?.toggleRecording();
              }
            }
            return KeyEventResult.handled;
          }
        } else if (event is KeyDownEvent) {
          if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
            if (isRecording) {
              coordinator?.cancelRecording();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          _micFocusNode.requestFocus();
          coordinator?.toggleRecording();
        },
        onLongPress: () {
          _micFocusNode.requestFocus();
          if (isRecording) {
            coordinator?.toggleRecording();
          } else if (widget.onLongPressMic != null) {
            widget.onLongPressMic?.call();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: isRecording ? 12 : 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: null,
            // boxShadow: [
            //   if (_isMicFocused)
            //     BoxShadow(
            //       color: scheme.primary.withValues(alpha: 0.35),
            //       blurRadius: 10,
            //       spreadRadius: 1,
            //     ),
            // ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                icon: isRecording ? AppIcons.close : AppIcons.micOn,
                color: foregroundColor,
                size: 18,
              ),
              if (isRecording) ...[
                const SizedBox(width: 6),
                Text(
                  '${remainingSeconds}s',
                  style: MoaiText.body(
                    context,
                    color: foregroundColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
