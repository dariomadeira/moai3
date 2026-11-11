import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/buttons/tv_glass_icon_pill.dart';

/// Agrega o saca el canal de Favoritos; con el canal ya favorito, el
/// corazón lleno en el acento.
class FavoriteButton extends StatelessWidget {
  final Channel channel;
  final FocusNode focusNode;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const FavoriteButton({
    super.key,
    required this.channel,
    required this.focusNode,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  @override
  Widget build(BuildContext context) {
    if (channel.isAdult) return const SizedBox.shrink();
    final isFav = context.select<FavoritesProvider, bool>(
      (state) => state.isFavorite(channel),
    );
    return TvGlassIconPill(
      focusNode: focusNode,
      onKeyLeft: onKeyLeft,
      onKeyRight: onKeyRight,
      onKeyUp: onKeyUp,
      onKeyDown: onKeyDown,
      icon: isFav
          ? MoaiIcons.tvFavoritesHeartSelected
          : MoaiIcons.tvFavoritesHeart,
      highlighted: isFav,
      onPressed: () =>
          context.read<FavoritesProvider>().toggleFavorite(channel),
    );
  }
}
