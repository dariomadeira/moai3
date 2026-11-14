import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_card_parts.dart';
import 'package:moai3/features/home/widgets/home_edge_pill.dart';
import 'package:moai3/features/home/widgets/home_row_window.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_friends_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/tv_common/friend_avatar.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_press_detector.dart';
import 'package:provider/provider.dart';

/// Tarjeta "Solicitudes" del Inicio: las solicitudes de amistad recibidas
/// (el Inicio sólo la muestra si hay alguna). ←/→ eligen una; OK la acepta
/// y OK mantenido pide confirmar y la rechaza, como en Gestionar amigos.
class HomeFriendRequestsItem extends StatefulWidget {
  const HomeFriendRequestsItem({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyUp,
    required this.onKeyDown,
  });

  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;

  @override
  State<HomeFriendRequestsItem> createState() => _HomeFriendRequestsItemState();
}

class _HomeFriendRequestsItemState extends State<HomeFriendRequestsItem> {
  late bool _focused = widget.focusNode.hasFocus;
  int _index = 0;
  bool _busy = false;

  Future<void> _accept(List<FriendInfo> requests) async {
    if (requests.isEmpty || _busy) return;
    final request = requests[_index];
    final party = context.read<WatchPartyProvider>();
    setState(() => _busy = true);
    try {
      await party.acceptFriendRequest(request);
      if (mounted) {
        MoaiSnackBar.show(
          context,
          message: LocaleKeys.friends_request_accepted.tr(
            namedArgs: {'name': request.displayName},
          ),
          icon: MoaiIcons.checkCircle,
        );
      }
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(List<FriendInfo> requests) async {
    if (requests.isEmpty || _busy) return;
    final request = requests[_index];
    final party = context.read<WatchPartyProvider>();
    if (!await confirmFriendReject(context, request) || !mounted) return;
    setState(() => _busy = true);
    try {
      await party.rejectFriendRequest(request);
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Los errores del provider traen la clave de traducción.
  void _showError(Object error) {
    final key = error.toString().replaceFirst('Exception: ', '').trim();
    MoaiSnackBar.showInfo(
      context,
      message: key.startsWith('friend_add_') || key.startsWith('friends_')
          ? key.tr()
          : LocaleKeys.friend_add_error_generic.tr(),
    );
  }

  /// Lo que la tarjeta muestra de cada solicitud.
  static bool _sameRequests(List<FriendInfo> a, List<FriendInfo> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].deviceId != b[i].deviceId ||
          a[i].userCode != b[i].userCode ||
          a[i].displayName != b[i].displayName ||
          a[i].isOnline != b[i].isOnline) {
        return false;
      }
    }
    return true;
  }

  // El provider avisa por cada cambio de los amigos (se conectan, cambian
  // de canal): la tarjeta sólo se redibuja si cambiaron las solicitudes.
  @override
  Widget build(BuildContext context) =>
      Selector<WatchPartyProvider, List<FriendInfo>>(
        selector: (_, party) => party.friendRequests,
        shouldRebuild: (before, after) => !_sameRequests(before, after),
        builder: (context, requests, _) => _buildCard(requests),
      );

  Widget _buildCard(List<FriendInfo> requests) {
    if (_index >= requests.length) {
      _index = requests.isEmpty ? 0 : requests.length - 1;
    }
    return TvPressDetector(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onPress: () => _accept(requests),
      onLongPress: () => _reject(requests),
      onLeft: () {
        if (_index > 0) {
          setState(() => _index--);
        } else {
          widget.onKeyLeft();
        }
        return true;
      },
      onRight: () {
        if (_index < requests.length - 1) setState(() => _index++);
        return true;
      },
      onUp: widget.onKeyUp,
      onDown: widget.onKeyDown,
      child: GestureDetector(
        onTap: () => _accept(requests),
        onLongPress: () => _reject(requests),
        child: HomeFriendRequestsCard(
          requests: requests,
          selectedIndex: _index,
          isFocused: _focused,
          busy: _busy,
        ),
      ),
    );
  }
}

/// Lo que se ve de la tarjeta: resumen a la izquierda y las solicitudes en
/// fila (como los amigos conectados de la tarjeta Amigos).
class HomeFriendRequestsCard extends StatelessWidget {
  const HomeFriendRequestsCard({
    super.key,
    required this.requests,
    required this.selectedIndex,
    this.isFocused = false,
    this.busy = false,
  });

  final List<FriendInfo> requests;
  final int selectedIndex;
  final bool isFocused;

  /// Aceptando o rechazando la elegida.
  final bool busy;

  /// REDISEÑO: el color de la tarjeta (su ícono).
  static const Color color = Color(0xFF8E4EC6);

  /// Mismo ancho y espacio que las fichas de la tarjeta Amigos.
  static const double _tileWidth = 236;
  static const double _tileGap = 10;

  @override
  Widget build(BuildContext context) {
    return MoaiGlass(
      borderRadius: 16,
      solid: true,
      elevated: false,
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        children: [
          SizedBox(
            width: HomeCardSummary.width,
            child: HomeCardSummary(
              label: LocaleKeys.home_friends_label.tr(),
              icon: MoaiIcons.friendRequests,
              color: color,
              title: LocaleKeys.home_requests_title.tr(),
              line: requests.length == 1
                  ? LocaleKeys.home_requests_count_one.tr()
                  : LocaleKeys.home_requests_count.tr(
                      namedArgs: {'count': '${requests.length}'},
                    ),
            ),
          ),
          const HomeCardDivider(),
          Expanded(
            child: requests.isEmpty
                ? const SizedBox.shrink()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      const step = _tileWidth + _tileGap;
                      final tilesWidth =
                          constraints.maxWidth - 2 * HomeEdgePill.width;
                      final visible = ((tilesWidth + _tileGap) ~/ step).clamp(
                        1,
                        requests.length,
                      );
                      final selected = selectedIndex.clamp(
                        0,
                        requests.length - 1,
                      );
                      return HomeRowWindow(
                        count: requests.length,
                        visible: visible,
                        selected: selected,
                        builder: (start) => Row(
                          children: [
                            HomeEdgePill(
                              icon: MoaiIcons.dpadLeft,
                              active: start > 0,
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  for (
                                    var i = start;
                                    i < start + visible;
                                    i++
                                  ) ...[
                                    if (i > start)
                                      const SizedBox(width: _tileGap),
                                    SizedBox(
                                      width: _tileWidth,
                                      child: _RequestTile(
                                        request: requests[i],
                                        isFocused: isFocused && i == selected,
                                        busy: busy && i == selected,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            HomeEdgePill(
                              icon: MoaiIcons.dpadRight,
                              active: start + visible < requests.length,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Una solicitud: avatar con el punto de estado, el nombre y "Quiere ser tu
/// amigo" (con foco, qué hace OK). Del ancho de las fichas de Amigos: el
/// código no entra (está en Gestionar amigos).
class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.request,
    required this.isFocused,
    required this.busy,
  });

  final FriendInfo request;
  final bool isFocused;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return MoaiGlass(
      borderRadius: 12,
      elevated: false,
      solid: true,
      focused: isFocused,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          FriendAvatar(userCode: request.userCode, online: request.isOnline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isFocused
                      ? LocaleKeys.home_requests_hint.tr()
                      : LocaleKeys.friends_request_subtitle.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          if (busy) ...[
            const SizedBox(width: 8),
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }
}
