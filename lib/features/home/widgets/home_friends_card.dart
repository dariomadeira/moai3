import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/features/home/widgets/home_card.dart';
import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
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
    if (online.isEmpty) return;
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
    final online = party.friends.where((f) => f.isOnline).toList();
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

  static const double _tileWidth = 200;
  static const double _tileGap = 10;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final hasFriends = friends.isNotEmpty;

    return HomeCard(
      glow: HomeCardColors.friends,
      // Con amigos el foco lo lleva el elegido, no la tarjeta.
      focused: isFocused && !hasFriends,
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        children: [
          SizedBox(
            width: 214,
            child: _Summary(count: friends.length, showHint: isFocused),
          ),
          Container(
            width: 1,
            height: 72,
            margin: const EdgeInsets.only(right: 16),
            color: scheme.onSurface.withValues(alpha: 0.08),
          ),
          Expanded(
            child: hasFriends
                ? _FriendStrip(
                    friends: friends,
                    selectedIndex: selectedIndex,
                    isFocused: isFocused,
                    myChannelId: myChannelId,
                    myChannelName: myChannelName,
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      LocaleKeys.home_friends_none.tr(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: MoaiText.body(
                        context,
                        color: scheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// "Miremos juntos" + "Amigos" en grande + cuántos están conectados (o,
/// con foco y amigos, qué hace OK).
class _Summary extends StatelessWidget {
  const _Summary({required this.count, required this.showHint});

  final int count;
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final muted = scheme.onSurfaceVariant;
    final hint = showHint && count > 0;
    final line = hint
        ? LocaleKeys.home_friends_hint.tr()
        : count == 0
        ? LocaleKeys.home_friends_online_none.tr()
        : count == 1
        ? LocaleKeys.home_friends_online_one.tr()
        : LocaleKeys.home_friends_online.tr(namedArgs: {'count': '$count'});

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.home_friends_label.tr(),
          style: MoaiText.body(
            context,
            color: muted,
            fontSize: 12,
            letterSpacing: 0.2,
          ),
        ),
        Row(
          children: [
            Icon(
              MoaiIcons.watchPartyFriends,
              size: MoaiIconSizes.xl,
              color: scheme.primary,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                LocaleKeys.home_friends_title.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MoaiText.display(
                  context,
                  color: scheme.onSurface,
                  fontSize: 34,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        Text(
          line,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MoaiText.body(
            context,
            color: hint ? scheme.primary : muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
        final tilesWidth = constraints.maxWidth - 2 * _Edge.width;
        final visible = ((tilesWidth + HomeFriendsCard._tileGap) ~/ step).clamp(
          1,
          friends.length,
        );
        final selected = selectedIndex.clamp(0, friends.length - 1);
        final start = (selected - visible + 1).clamp(
          0,
          friends.length - visible,
        );

        return Row(
          children: [
            _Edge(icon: MoaiIcons.dpadLeft, active: start > 0),
            Expanded(
              child: Row(
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
            _Edge(
              icon: MoaiIcons.dpadRight,
              active: start + visible < friends.length,
            ),
          ],
        );
      },
    );
  }
}

class _Edge extends StatelessWidget {
  const _Edge({required this.icon, required this.active});

  static const double width = 28;

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return SizedBox(
      width: width,
      child: Icon(
        icon,
        size: MoaiIconSizes.lg,
        color: active
            ? scheme.primary
            : scheme.onSurfaceVariant.withValues(alpha: 0.15),
      ),
    );
  }
}

/// Un amigo: nombre arriba y el canal que mira abajo. Si mira lo mismo que
/// yo va teñido del acento con "Con vos".
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
    final channel = friend.displayChannelName;

    return MoaiGlass(
      borderRadius: 12,
      elevated: false,
      solid: true,
      tint: withMe ? scheme.primary : null,
      focused: isFocused,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                MoaiIcons.person,
                size: MoaiIconSizes.md,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  friend.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (withMe)
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
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                MoaiIcons.tv,
                size: MoaiIconSizes.sm,
                color: channel == null
                    ? scheme.onSurfaceVariant
                    : scheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  channel ?? LocaleKeys.home_friends_no_channel.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.body(
                    context,
                    color: channel == null
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                    fontSize: 12.5,
                    fontWeight: channel == null
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
