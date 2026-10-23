import 'dart:async';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/services/watch_party_voice_coordinator.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Componente de la barra superior en Modo TV para la funcionalidad "Mirar juntos".
///
/// Muestra dinámicamente:
/// 1. Área Audio Entrante ("{amigo} hablando..."): Idéntica en colores y estilos al Overlay (scheme.primary y scheme.onPrimary).
/// 2. Área Micrófono: Enfocable por D-Pad con respuestas completas de navegación.
class TvWatchPartyHeaderBar extends StatefulWidget {
  final String? channelName;
  final FocusNode? micFocusNode;
  final VoidCallback? onLongPressMic;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const TvWatchPartyHeaderBar({
    super.key,
    this.channelName,
    this.micFocusNode,
    this.onLongPressMic,
    this.onKeyLeft,
    this.onKeyUp,
    this.onKeyDown,
  });

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
    final watchPartyProvider = context.watch<WatchPartyProvider?>();
    final coordinator = context.watch<WatchPartyVoiceCoordinator?>();

    final watchPartyEnabled = watchPartyProvider?.enabled ?? false;

    final hasFriendsInChannel = watchPartyEnabled &&
        (watchPartyProvider?.hasFriendsInSameChannel ?? false);
    final isRecording = watchPartyEnabled &&
        (coordinator?.isRecording ?? false);
    final isPlaying = watchPartyEnabled &&
        (coordinator?.isPlaying ?? false);
    final speakerName = coordinator?.currentSpeakerName;

    final showYellowMic = hasFriendsInChannel;

    final channelName = widget.channelName;
    final hasChannelName = channelName != null && channelName.trim().isNotEmpty;

    if (!showYellowMic && !isPlaying && !hasChannelName) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
        child: Row(
          children: [
            if (hasChannelName) ...[
              Expanded(
                child: Text(
                  channelName.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.display(
                    context,
                    color: scheme.onSurface,
                    fontSize: 28,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // 1. Audio Entrante ("{amigo} hablando...")
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
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          MoaiIcons.voiceSelection,
                          color: scheme.onPrimary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              speakerName != null
                                  ? LocaleKeys.watch_party_friend_speaking.tr(namedArgs: {'name': speakerName})
                                  : LocaleKeys.watch_party_listening_audio.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MoaiText.body(
                                context,
                                color: scheme.onPrimary,
                                fontSize: 12,
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

        final isActionButton = TvKeyHandler.isActionKey(key);

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
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRecording ? MoaiIcons.stopRounded : MoaiIcons.mic,
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
