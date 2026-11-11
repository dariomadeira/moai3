import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_card_parts.dart';
import 'package:moai3/features/home/widgets/home_edge_pill.dart';
import 'package:moai3/features/home/widgets/home_row_window.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_logo.dart';
import 'package:moai3/widgets/dialogs/tv_friends_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/tv_common/friend_avatar.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';
import 'package:moai3/widgets/tv_common/tv_press_detector.dart';
import 'package:provider/provider.dart';

/// Tarjeta "Amigos" del Inicio (sólo con Miremos Juntos activado): qué
/// amigos están conectados y qué canal miran. ←/→ eligen un amigo y OK
/// sintoniza su canal, para mirarlo juntos y hablar.
class HomeFriendsItem extends StatefulWidget {
  const HomeFriendsItem({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyUp,
    required this.onKeyDown,
    this.onTuneChannel,
  });

  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyUp;
  final VoidCallback onKeyDown;

  /// Sintoniza el canal del amigo (sin él, lo elige en [ChannelProvider]).
  final ValueChanged<Channel>? onTuneChannel;

  /// El canal del amigo en la lista propia: primero por id y, si vino de
  /// otra extensión, por nombre. Sin canal o con uno de adultos, null.
  static Channel? channelOf(FriendInfo friend, List<Channel> channels) {
    if (friend.displayChannelName == null) return null;
    for (final c in channels) {
      if (c.id == friend.currentChannelId) return c.isAdult ? null : c;
    }
    for (final c in channels) {
      if (!c.isAdult && friend.isWatchingSameChannel(c.id, c.name)) return c;
    }
    return null;
  }

  @override
  State<HomeFriendsItem> createState() => _HomeFriendsItemState();
}

class _HomeFriendsItemState extends State<HomeFriendsItem> {
  late bool _focused = widget.focusNode.hasFocus;
  int _index = 0;

  void _press(List<FriendInfo> online) {
    // Nadie conectado: el botón "Gestionar amigos" abre el modal.
    if (online.isEmpty) {
      TvFriendsDialog.show(context, onTuneChannel: widget.onTuneChannel);
      return;
    }
    final friend = online[_index];
    final channelName = friend.displayChannelName;
    if (channelName == null) {
      MoaiSnackBar.showInfo(
        context,
        message: LocaleKeys.home_friends_not_watching.tr(
          namedArgs: {'name': friend.displayName},
        ),
      );
      return;
    }
    final channels = context.read<ChannelProvider>();
    final channel = HomeFriendsItem.channelOf(friend, channels.allChannels);
    if (channel == null) {
      MoaiSnackBar.showInfo(
        context,
        message: LocaleKeys.home_friends_channel_missing.tr(
          namedArgs: {'channel': channelName},
        ),
      );
      return;
    }
    if (widget.onTuneChannel != null) {
      widget.onTuneChannel!(channel);
    } else {
      channels.selectChannel(channel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final party = context.watch<WatchPartyProvider>();
    final online = party.mutualFriends.where((f) => f.isOnline).toList();
    if (_index >= online.length) {
      _index = online.isEmpty ? 0 : online.length - 1;
    }
    return TvPressDetector(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onPress: () => _press(online),
      onLeft: () {
        if (_index > 0) {
          setState(() => _index--);
        } else {
          widget.onKeyLeft();
        }
        return true;
      },
      onRight: () {
        if (_index < online.length - 1) setState(() => _index++);
        return true;
      },
      onUp: widget.onKeyUp,
      onDown: widget.onKeyDown,
      child: GestureDetector(
        onTap: () => _press(online),
        child: HomeFriendsCard(
          friends: online,
          selectedIndex: _index,
          isFocused: _focused,
          myChannelId: party.currentChannelId,
          myChannelName: party.currentChannelName,
        ),
      ),
    );
  }
}

/// Lo que se ve de la tarjeta: resumen a la izquierda y los amigos
/// conectados en fila, con el canal que miran.
class HomeFriendsCard extends StatelessWidget {
  const HomeFriendsCard({
    super.key,
    required this.friends,
    required this.selectedIndex,
    this.isFocused = false,
    this.myChannelId,
    this.myChannelName,
  });

  /// Amigos conectados.
  final List<FriendInfo> friends;
  final int selectedIndex;
  final bool isFocused;

  /// Mi canal, para marcar a los que miran lo mismo.
  final String? myChannelId;
  final String? myChannelName;

  /// REDISEÑO: el color de la tarjeta (su ícono).
  static const Color color = Color(0xFF116699);

  /// Mismo ancho, espacio y relleno que los eventos de Hoy.
  static const double _tileWidth = 236;
  static const double _tileGap = 10;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final hasFriends = friends.isNotEmpty;

    // REDISEÑO: el cristal de las tarjetas del Inicio, sin halo de color
    // (como el clima). Sin amigos conectados se enfoca igual: abajo del
    // aviso va el botón "Gestionar amigos" (OK sobre la tarjeta).
    return MoaiGlass(
      borderRadius: 16,
      solid: true,
      elevated: false,
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        children: [
          // La línea no cambia con el foco: OK se sobreentiende.
          SizedBox(
            width: HomeCardSummary.width,
            child: HomeCardSummary(
              label: LocaleKeys.home_friends_label.tr(),
              icon: MoaiIcons.friends,
              color: color,
              title: LocaleKeys.home_friends_title.tr(),
              line: switch (friends.length) {
                0 => LocaleKeys.home_friends_online_none.tr(),
                1 => LocaleKeys.home_friends_online_one.tr(),
                final count => LocaleKeys.home_friends_online.tr(
                  namedArgs: {'count': '$count'},
                ),
              },
            ),
          ),
          const HomeCardDivider(),
          Expanded(
            child: hasFriends
                ? _FriendStrip(
                    friends: friends,
                    selectedIndex: selectedIndex,
                    isFocused: isFocused,
                    myChannelId: myChannelId,
                    myChannelName: myChannelName,
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          LocaleKeys.home_friends_none.tr(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: MoaiText.body(
                            context,
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Como "Configurar" de Descuentos sin bancos: no
                        // toma el foco, lo enciende el de la tarjeta.
                        HomeGlassButton(
                          icon: MoaiIcons.watchPartyFriends,
                          label: LocaleKeys.settings_tv_manage_friends.tr(),
                          focused: isFocused,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Fila de amigos con ventana: se corre para que el elegido siempre se vea.
/// Las flechas de los costados avisan que hay más de ese lado.
class _FriendStrip extends StatelessWidget {
  const _FriendStrip({
    required this.friends,
    required this.selectedIndex,
    required this.isFocused,
    this.myChannelId,
    this.myChannelName,
  });

  final List<FriendInfo> friends;
  final int selectedIndex;
  final bool isFocused;
  final String? myChannelId;
  final String? myChannelName;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const step = HomeFriendsCard._tileWidth + HomeFriendsCard._tileGap;
        // Las flechas ocupan su lugar siempre, así la fila no salta.
        final tilesWidth = constraints.maxWidth - 2 * HomeEdgePill.width;
        final visible = ((tilesWidth + HomeFriendsCard._tileGap) ~/ step).clamp(
          1,
          friends.length,
        );
        final selected = selectedIndex.clamp(0, friends.length - 1);
        return HomeRowWindow(
          count: friends.length,
          visible: visible,
          selected: selected,
          builder: (start) => Row(
            children: [
              HomeEdgePill(icon: MoaiIcons.dpadLeft, active: start > 0),
              Expanded(
                child: Row(
                  // Siempre desde la izquierda: según el margen de calibración
                  // de cada TV entran 1 o 2 fichas, y centrar las movía.
                  children: [
                    for (var i = start; i < start + visible; i++) ...[
                      if (i > start)
                        const SizedBox(width: HomeFriendsCard._tileGap),
                      SizedBox(
                        width: HomeFriendsCard._tileWidth,
                        child: _FriendTile(
                          friend: friends[i],
                          isFocused: isFocused && i == selected,
                          withMe: friends[i].isWatchingSameChannel(
                            myChannelId,
                            myChannelName,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              HomeEdgePill(
                icon: MoaiIcons.dpadRight,
                active: start + visible < friends.length,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Un amigo: avatar con su inicial y el punto de conectado, el nombre y el
/// canal que mira, y a la derecha el logo de ese canal si está en la lista
/// propia. Si mira lo mismo que yo va teñido del acento con "Con vos".
class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.isFocused,
    required this.withMe,
  });

  final FriendInfo friend;
  final bool isFocused;
  final bool withMe;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final channelName = friend.displayChannelName;
    final channels = context.select(
      (ChannelProvider? p) => p?.allChannels ?? const <Channel>[],
    );
    final logoUrl = HomeFriendsItem.channelOf(friend, channels)?.logoUrl.trim();

    return MoaiGlass(
      borderRadius: 12,
      elevated: false,
      solid: true,
      tint: withMe ? scheme.primary : null,
      focused: isFocused,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          FriendAvatar(userCode: friend.userCode),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.displayName,
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
                Row(
                  children: [
                    if (withMe) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: moaiGlassChipDecoration(
                          scheme,
                          highlighted: true,
                        ),
                        child: Text(
                          LocaleKeys.home_friends_with_you.tr(),
                          style: MoaiText.body(
                            context,
                            color: scheme.onSurface,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        channelName ??
                            (friend.isPlayingArcade
                                    ? LocaleKeys.home_friends_playing
                                    : LocaleKeys.home_friends_no_channel)
                                .tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // El logo del canal: lo que se va a ver con OK.
          if (logoUrl != null && logoUrl.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TvListCardLeadingLogo(
                logoUrl: logoUrl,
                width: 48,
                height: 36,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
