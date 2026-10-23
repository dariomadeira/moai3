import 'dart:async';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/services/modal_route_tracker.dart';
import 'package:moai3/services/watch_party_voice_coordinator.dart';
import 'package:moai3/state/tv_settings_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_friends_dialog.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';

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

class _WatchPartyOverlayState extends State<WatchPartyOverlay> {
  late final FocusNode _micFocusNode;
  bool _ownsFocusNode = false;
  bool _isMicFocused = false;

  Timer? _longPressTimer;
  bool _isKeyDown = false;
  bool _longPressTriggered = false;

  StreamSubscription<String>? _notificationSubscription;
  String? _activeNotificationMessage;
  Timer? _notificationDisplayTimer;
  final List<String> _pendingNotifications = [];
  WatchPartyProvider? _subscribedProvider;

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
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isMicFocused = _micFocusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _notificationDisplayTimer?.cancel();
    _longPressTimer?.cancel();
    _micFocusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) {
      _micFocusNode.dispose();
    }
    super.dispose();
  }

  void _enqueueNotification(String message) {
    if (_activeNotificationMessage == null) {
      _showNotification(message);
    } else {
      _pendingNotifications.add(message);
    }
  }

  void _showNotification(String message) {
    if (!mounted) return;
    setState(() {
      _activeNotificationMessage = message;
    });

    _notificationDisplayTimer?.cancel();
    _notificationDisplayTimer = Timer(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      setState(() {
        _activeNotificationMessage = null;
      });

      if (_pendingNotifications.isNotEmpty) {
        final next = _pendingNotifications.removeAt(0);
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _showNotification(next);
          }
        });
      }
    });
  }

  Future<void> _openFriendsModal(
    BuildContext context,
    WatchPartyVoiceCoordinator? coordinator,
  ) async {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _isKeyDown = false;

    // Desenfocar explícitamente el micrófono para ceder el foco al modal
    _micFocusNode.unfocus();

    coordinator?.pauseQueue();
    try {
      await TvFriendsDialog.show(context);
    } finally {
      coordinator?.resumeQueue();
      if (mounted &&
          !ModalRouteTracker.instance.hasActiveModal &&
          _micFocusNode.canRequestFocus) {
        _micFocusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Va encima del video: escuchar solo lo que cambia lo visible (SPEC-50 §6.1).
    final watchParty = context.read<WatchPartyProvider>();
    final visible = context.select(
      (WatchPartyProvider p) => p.enabled && p.hasFriendsInSameChannel,
    );
    final coordinator = widget.coordinator ??
        (context.watch<WatchPartyVoiceCoordinator?>());

    if (_subscribedProvider != watchParty) {
      _notificationSubscription?.cancel();
      _subscribedProvider = watchParty;
      _notificationSubscription =
          watchParty.joinedChannelNotificationsStream.listen(_enqueueNotification);
    }

    // Regla de visibilidad SPEC-37: Si no está habilitado o no hay amigos en este canal, ocultar.
    if (!visible) {
      return const SizedBox.shrink();
    }

    // Auto-enfocar el botón de micrófono al aparecer en pantalla completa
    // (Únicamente si NO hay un modal o diálogo activo)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !ModalRouteTracker.instance.hasActiveModal &&
          _micFocusNode.canRequestFocus &&
          !_micFocusNode.hasFocus) {
        _micFocusNode.requestFocus();
      }
    });



    final isRecording = coordinator?.isRecording ?? false;
    final isPlaying = coordinator?.isPlaying ?? false;
    final speakerName = coordinator?.currentSpeakerName;

    final scheme = Theme.of(context).colorScheme;

    final String? displayNotification = _activeNotificationMessage != null
        ? LocaleKeys.watch_party_friend_joined
            .tr(namedArgs: {'name': _activeNotificationMessage!})
        : null;

    final (overscanX, overscanY) = context.select(
      (TvSettingsProvider? s) =>
          (s?.overlapPaddingX ?? 20.0, s?.overlapPaddingY ?? 20.0),
    );

    final topOffset = overscanY + 12.0;
    final leftOffset = overscanX + 16.0;
    final rightOffset = overscanX + 16.0;

    return Positioned(
      top: topOffset,
      left: leftOffset,
      right: rightOffset,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Notificación Izquierda: Amigo entrando al canal (Alineado a la derecha en su mitad)
          Expanded(
            child: Align(
              alignment: Alignment.topRight,
              child: displayNotification != null
                  ? _buildJoinedNotificationChip(context, displayNotification, scheme)
                  : const SizedBox.shrink(),
            ),
          ),

          const SizedBox(width: 14),

          // 2. Botón Central: Micrófono (Siempre exactamente en el centro horizontal)
          _buildMicButton(context, coordinator, isRecording, scheme),

          const SizedBox(width: 14),

          // 3. Chip Derecho: Audio entrante (Alineado a la izquierda en su mitad)
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: isPlaying
                  ? _buildIncomingAudioChip(context, speakerName, scheme)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinedNotificationChip(
    BuildContext context,
    String message,
    ColorScheme scheme,
  ) {
    // Usar colores idénticos a MoaiSnackBar (scheme.primary y scheme.onPrimary)
    final bg = scheme.primary;
    final fg = scheme.onPrimary;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.48),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MoaiIcons.person,
              color: fg,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MoaiText.body(
                  context,
                  color: fg,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMicButton(
    BuildContext context,
    WatchPartyVoiceCoordinator? coordinator,
    bool isRecording,
    ColorScheme scheme,
  ) {
    // Cuenta hacia atrás de 30 a 0 segundos
    final remainingSeconds =
        (30 - (coordinator?.recordingSeconds ?? 0)).clamp(0, 30);

    // Color plano y sólido (sin transparencias ni bordes)
    final backgroundColor = _isMicFocused
        ? scheme.tertiary
        : scheme.tertiaryContainer;

    final iconColor = _isMicFocused
        ? scheme.onTertiary
        : (isRecording ? scheme.error : scheme.onTertiaryContainer);

    final Widget micContent = Container(
      width: 48,
      height: 30,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _isMicFocused
              ? scheme.primary
              : scheme.outlineVariant.withValues(alpha: 0.48),
        ),
      ),
      child: Center(
        child: Icon(
          isRecording ? MoaiIcons.stopRounded : MoaiIcons.mic,
          color: iconColor,
          size: 18,
        ),
      ),
    );

    return Focus(
      focusNode: _micFocusNode,
      onKeyEvent: (node, event) {
        final key = event.logicalKey;
        final isActionButton = TvKeyHandler.isActionKey(key);

        if (isActionButton) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            if (event is KeyDownEvent && !_isKeyDown) {
              _isKeyDown = true;
              _longPressTriggered = false;
              _longPressTimer?.cancel();
              if (!isRecording) {
                // Long-press abre el modal solo si NO está grabando
                _longPressTimer = Timer(const Duration(milliseconds: 600), () {
                  _longPressTriggered = true;
                  _openFriendsModal(context, coordinator);
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
                // Toque común: alternar grabación
                coordinator?.toggleRecording();
              }
            }
            return KeyEventResult.handled;
          }
        } else if (event is KeyDownEvent) {
          if (key == LogicalKeyboardKey.escape ||
              key == LogicalKeyboardKey.goBack) {
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
            // Si está grabando, el long-press actúa como toque común (detener grabación)
            coordinator?.toggleRecording();
          } else {
            // Si NO está grabando, abre el modal de amigos
            _openFriendsModal(context, coordinator);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            micContent,
            if (isRecording) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black, // Color sólido 100% opaco
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '0:${remainingSeconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
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
    String? speakerName,
    ColorScheme scheme,
  ) {
    // Usar colores idénticos a MoaiSnackBar (scheme.primary y scheme.onPrimary)
    final bg = scheme.primary;
    final fg = scheme.onPrimary;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.48),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MoaiIcons.voiceSelection,
              color: fg,
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                speakerName != null
                    ? LocaleKeys.watch_party_friend_speaking
                        .tr(namedArgs: {'name': speakerName})
                    : LocaleKeys.watch_party_listening_audio.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MoaiText.body(
                  context,
                  color: fg,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
