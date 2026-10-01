import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/services/watch_party_voice_coordinator.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:provider/provider.dart';

/// Overlay de voz y presencia en pantalla completa para "Miremos Juntos" (SPEC-37).
/// Se muestra únicamente si:
/// 1. Watch Party está activado.
/// 2. El reproductor está en pantalla completa.
/// 3. Hay al menos un amigo sintonizando el mismo canal.
class WatchPartyOverlay extends StatefulWidget {
  final WatchPartyVoiceCoordinator? coordinator;
  final FocusNode? micFocusNode;

  const WatchPartyOverlay({
    super.key,
    this.coordinator,
    this.micFocusNode,
  });

  @override
  State<WatchPartyOverlay> createState() => _WatchPartyOverlayState();
}

class _WatchPartyOverlayState extends State<WatchPartyOverlay>
    with SingleTickerProviderStateMixin {
  late final FocusNode _micFocusNode;
  bool _ownsFocusNode = false;
  bool _isMicFocused = false;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.micFocusNode != null) {
      _micFocusNode = widget.micFocusNode!;
    } else {
      _micFocusNode = FocusNode(debugLabel: 'WatchPartyMicButton');
      _ownsFocusNode = true;
    }

    _micFocusNode.addListener(_onFocusChange);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isMicFocused = _micFocusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _micFocusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) {
      _micFocusNode.dispose();
    }
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final watchParty = context.watch<WatchPartyProvider>();
    final coordinator = widget.coordinator ??
        (context.watch<WatchPartyVoiceCoordinator?>());

    // Regla de visibilidad SPEC-37: Si no está habilitado o no hay amigos en este canal, ocultar
    if (!watchParty.enabled || !watchParty.hasFriendsInSameChannel) {
      return const SizedBox.shrink();
    }

    // Auto-enfocar el botón de micrófono al aparecer en pantalla completa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _micFocusNode.canRequestFocus && !_micFocusNode.hasFocus) {
        _micFocusNode.requestFocus();
      }
    });

    final friends = watchParty.friendsWatchingCurrentChannel;
    final isRecording = coordinator?.isRecording ?? false;
    final isPlaying = coordinator?.isPlaying ?? false;
    final speakerName = coordinator?.currentSpeakerName;

    if (isRecording && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isRecording && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    final scheme = Theme.of(context).colorScheme;

    return Positioned(
      top: 32,
      left: 0,
      right: 0,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Chip Izquierdo: Amigos mirando
            _buildFriendsWatchingChip(context, friends, scheme),

            const SizedBox(width: 16),

            // 2. Botón Central: Toggle-to-Talk (Mic / Stop)
            _buildMicButton(context, coordinator, isRecording, scheme),

            const SizedBox(width: 16),

            // 3. Chip Derecho: Audio entrante
            if (isPlaying && speakerName != null)
              _buildIncomingAudioChip(context, speakerName, scheme)
            else
              // Espaciador para balance visual centrado
              const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsWatchingChip(
    BuildContext context,
    List<FriendInfo> friends,
    ColorScheme scheme,
  ) {
    final String label;
    final firstFriend = friends.first;
    final firstName = firstFriend.nickname ?? firstFriend.userCode;

    if (friends.length == 1) {
      label = '$firstName está viendo';
    } else if (friends.length == 2) {
      label = '$firstName y 1 más están viendo';
    } else {
      label = '$firstName y ${friends.length - 1} más están viendo';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4CAF50), // Verde online brillante
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: MoaiText.body(
              context,
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton(
    BuildContext context,
    WatchPartyVoiceCoordinator? coordinator,
    bool isRecording,
    ColorScheme scheme,
  ) {
    Widget micContent = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isRecording
            ? scheme.error
            : (_isMicFocused
                ? scheme.primary.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.75)),
        border: Border.all(
          color: isRecording
              ? Colors.white
              : (_isMicFocused ? scheme.primary : scheme.primary.withValues(alpha: 0.6)),
          width: _isMicFocused ? 3.5 : 2.5,
        ),
        boxShadow: isRecording
            ? [
                BoxShadow(
                  color: scheme.error.withValues(alpha: 0.7),
                  blurRadius: 16,
                  spreadRadius: 3,
                )
              ]
            : (_isMicFocused
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    )
                  ]
                : null),
      ),
      child: Center(
        child: isRecording
            ? const Icon(
                Icons.stop_rounded,
                color: Colors.white,
                size: 32,
              )
            : Icon(
                Symbols.mic,
                color: _isMicFocused ? scheme.primary : Colors.white,
                size: 28,
              ),
      ),
    );

    if (isRecording) {
      micContent = ScaleTransition(
        scale: _pulseAnimation,
        child: micContent,
      );
    }

    return Focus(
      focusNode: _micFocusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            coordinator?.toggleRecording();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            micContent,
            if (isRecording) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '0:${(coordinator?.recordingSeconds ?? 0).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingAudioChip(
    BuildContext context,
    String speakerName,
    ColorScheme scheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.secondary.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.secondary.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.volume_up,
            color: scheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            '$speakerName hablando...',
            style: MoaiText.body(
              context,
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
