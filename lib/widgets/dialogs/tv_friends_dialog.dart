import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/features/home/widgets/collapsed_panel_tab_preview.dart';
import 'package:moai3/features/home/widgets/home_friends_card.dart';
import 'package:moai3/features/home/widgets/tv_accordion_row_preview.dart';
import 'package:moai3/focus/focus_requester.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/models/friend_info.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_empty_state_card.dart';
import 'package:moai3/widgets/cards/tv_list_card_leading_logo.dart';
import 'package:moai3/widgets/tv_common/friend_avatar.dart';
import 'package:moai3/widgets/tv_common/tv_press_detector.dart';
import 'package:moai3/widgets/tv_common/tv_value_chip.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/lists/tv_windowed_list.dart';
import 'package:moai3/widgets/tv_common/moai_count_badge.dart';
import 'package:moai3/widgets/tv_common/moai_status_tag.dart';
import 'package:moai3/widgets/tv_common/tv_m3.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

part 'tv_friends/tv_friends_sections.dart';
part 'tv_friends/friend_tile.dart';
part 'tv_friends/request_tile.dart';
part 'tv_friends/friends_search.dart';

part 'tv_friends/tv_friends_actions.dart';
part 'tv_friends/tv_friends_search_flow.dart';

/// Diálogo de amigos de "Mirar juntos": tres paneles en acordeón, como
/// Ajustes. ←/→ pasan de panel, ↑/↓ recorren el panel abierto y ↓ al final
/// va a Cerrar.
///
/// 1. Amigos: los que también te agregaron, los conectados primero, con el
///    canal que miran. OK va a su canal ([onTuneChannel]) para mirar
///    juntos; OK mantenido pide confirmar y lo elimina.
/// 2. Solicitudes: las que te mandaron. OK acepta; OK mantenido pide
///    confirmar y la rechaza (hasta que te vuelva a agregar). Si no, quedan.
/// 3. Agregar y buscar: el código de un amigo (Agregar le manda la
///    solicitud) y buscar por apodo; OK sobre un resultado se la manda.
///
/// La lista se mantiene al día sola (Realtime y el sondeo del provider).
class TvFriendsDialog extends StatefulWidget {
  const TvFriendsDialog({super.key, this.onTuneChannel});

  /// Sintoniza el canal de un amigo (y lleva al visor). Sin él, lo elige en
  /// [ChannelProvider].
  final ValueChanged<Channel>? onTuneChannel;

  static Future<void> show(
    BuildContext context, {
    ValueChanged<Channel>? onTuneChannel,
  }) {
    return showTvGeneralDialog(
      context: context,
      barrierLabel: 'TvFriendsDialog',
      builder: (dialogContext) => TvFriendsDialog(onTuneChannel: onTuneChannel),
    );
  }

  /// Paneles del acordeón.
  static const int friendsPanel = 0;
  static const int requestsPanel = 1;
  static const int addPanel = 2;
  static const int panelCount = 3;

  @override
  State<TvFriendsDialog> createState() => _TvFriendsDialogState();
}

class _TvFriendsDialogState extends State<TvFriendsDialog> {
  static const int _windowSize = 4;

  /// Resultados de buscar visibles a la vez (debajo de los dos campos).
  static const int _searchWindowSize = 2;

  /// Alto de cada fila de Amigos y Solicitudes (la ficha y su espacio).
  static const double _friendExtent = _FriendTile.height + 8;

  /// Alto del acordeón: justo [_windowSize] filas y el relleno del panel,
  /// así el espacio de arriba y de abajo de la lista es el mismo.
  static const double _accordionHeight =
      2 * _TvFriendsSections._panelPadding + _windowSize * _friendExtent;

  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode(
    debugLabel: 'friends_modal_code_input',
  );
  final FocusNode _addFocus = FocusNode(debugLabel: 'friends_modal_add_btn');

  /// Buscar por apodo (panel Agregar y buscar).
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode(
    debugLabel: 'friends_modal_search_input',
  );
  final GlobalKey<TvWindowedListState<FriendInfo>> _searchListKey =
      GlobalKey<TvWindowedListState<FriendInfo>>();

  /// La X al lado del buscador: borra la búsqueda.
  final FocusNode _clearFocus = FocusNode(
    debugLabel: 'friends_modal_search_clear',
  );

  /// Estado vacío del lugar de los resultados (sin resultados, faltan
  /// letras o falló).
  final FocusNode _searchEmptyFocus = FocusNode(
    debugLabel: 'friends_modal_search_empty',
  );

  /// Lo último que se buscó y lo que trajo (null: todavía no se buscó).
  String _searchQuery = '';
  List<FriendInfo>? _searchResults;
  bool _searching = false;
  int _searchIndex = 0;

  /// Aviso en el lugar de los resultados en vez de la lista (clave de
  /// traducción): faltan letras o la búsqueda falló.
  String? _searchNotice;

  final FocusNode _closeFocus = FocusNode(
    debugLabel: 'friends_modal_close_btn',
  );

  /// Un nodo por panel: recibe el foco si el panel no tiene nada que enfocar
  /// (p. ej. vacío) y maneja ←/→ que suben desde adentro.
  final List<FocusNode> _panelFocus = List.generate(
    TvFriendsDialog.panelCount,
    (i) => FocusNode(debugLabel: 'friends_modal_panel_$i'),
  );

  /// Estado vacío de cada panel ([TvEmptyStateCard]): se enfoca cuando la
  /// lista no tiene nada; las flechas suben al Focus del panel.
  final List<FocusNode> _emptyFocus = List.generate(
    TvFriendsDialog.panelCount,
    (i) => FocusNode(debugLabel: 'friends_modal_empty_$i'),
  );
  final GlobalKey<TvWindowedListState<FriendInfo>> _friendsListKey =
      GlobalKey<TvWindowedListState<FriendInfo>>();
  final GlobalKey<TvWindowedListState<FriendInfo>> _requestsListKey =
      GlobalKey<TvWindowedListState<FriendInfo>>();

  late final _focus = FocusRequester(isMounted: () => mounted);

  int _panel = TvFriendsDialog.friendsPanel;

  /// Dónde quedó el foco en cada lista (para volver al mismo lugar).
  int _friendsIndex = 0;
  int _requestsIndex = 0;

  /// Error debajo del acordeón (clave de traducción).
  String? _errorMessage;
  bool _isSubmitting = false;

  /// Agregando por código (la ruedita del botón Agregar amigo).
  bool _addingByCode = false;

  /// La clave de traducción de un error del provider (sus excepciones
  /// traen la clave); si no es una conocida, [fallback].
  static String _errorKey(
    Object error, {
    String fallback = LocaleKeys.friend_add_error_generic,
  }) {
    final key = error.toString().replaceFirst('Exception: ', '').trim();
    return key.startsWith('friend_add_') || key.startsWith('friends_')
        ? key
        : fallback;
  }

  /// Los amigos del panel: los conectados primero.
  List<FriendInfo> _friendsOf(WatchPartyProvider watchParty) {
    final friends = watchParty.mutualFriends;
    return [
      ...friends.where((f) => f.isOnline),
      ...friends.where((f) => !f.isOnline),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _focusPanel();
      // Siempre abre en Amigos, aunque esté vacío (muestra el estado vacío).
      await context.read<WatchPartyProvider>().loadFriends(showLoading: true);
      // Si llegaron amigos, el foco pasa del estado vacío a la lista.
      if (mounted) _focusPanel();
    });
  }

  @override
  void dispose() {
    _focus.cancel();
    _codeController.dispose();
    _codeFocus.dispose();
    _addFocus.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _clearFocus.dispose();
    _searchEmptyFocus.dispose();
    _closeFocus.dispose();
    for (final node in [..._panelFocus, ..._emptyFocus]) {
      node.dispose();
    }
    super.dispose();
  }

  /// Abre [index] (si existe) y le pasa el foco.
  void _selectPanel(int index) {
    if (index < 0 || index >= TvFriendsDialog.panelCount) return;
    // El error de un panel no queda colgado en el siguiente.
    if (index != _panel) {
      setState(() {
        _panel = index;
        _errorMessage = null;
      });
    }
    _focusPanel();
  }

  /// [node] está armado y puede tomar el foco ahora.
  static bool _focusable(FocusNode node) =>
      (node.context?.mounted ?? false) && node.canRequestFocus;

  /// Enfoca lo que corresponde en el panel abierto: donde había quedado en
  /// la lista, el campo del código o, si está vacío, su estado vacío.
  void _focusPanel() {
    _focus.request(() {
      // El acordeón deja armados los paneles cerrados, pero sin foco
      // (ExcludeFocus). Hasta que reconstruya con el panel nuevo abierto,
      // pedirle foco a algo de adentro no hace nada y el foco cae en el
      // historial del modal (Cerrar): se espera al cuadro siguiente.
      if (!_focusable(_panelFocus[_panel])) return false;
      final watchParty = context.read<WatchPartyProvider>();
      switch (_panel) {
        case TvFriendsDialog.friendsPanel:
          final list = _friendsListKey.currentState;
          if (_friendsOf(watchParty).isNotEmpty) {
            if (list == null) return false;
            list.ensureVisible(_friendsIndex);
            return true;
          }
        case TvFriendsDialog.requestsPanel:
          final list = _requestsListKey.currentState;
          if (watchParty.friendRequests.isNotEmpty) {
            if (list == null) return false;
            list.ensureVisible(_requestsIndex);
            return true;
          }
        case TvFriendsDialog.addPanel:
          if (!_focusable(_codeFocus)) return false;
          _codeFocus.requestFocus();
          return true;
      }
      // Lista vacía: su tarjeta de estado vacío (si se acaba de vaciar,
      // todavía no se armó: reintenta en el cuadro siguiente).
      final empty = _emptyFocus[_panel];
      if (!_focusable(empty)) return false;
      empty.requestFocus();
      return true;
      // En el acto (sin esperar un cuadro, que puede no venir); si el panel
      // todavía no se armó, reintenta en los siguientes.
    }, immediate: true);
  }

  /// Hay algo para borrar: sólo entonces se ve la X.
  bool get _canClearSearch =>
      _searchController.text.isNotEmpty ||
      _searchResults != null ||
      _searchNotice != null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final watchParty = context.watch<WatchPartyProvider>();
    final friends = _friendsOf(watchParty);
    final requests = watchParty.friendRequests;
    final online = friends.where((f) => f.isOnline).length;

    final titles = [
      LocaleKeys.friends_tab_friends.tr(),
      LocaleKeys.friends_tab_requests.tr(),
      LocaleKeys.friends_tab_add.tr(),
    ];
    const icons = [
      MoaiIcons.friends,
      MoaiIcons.friendRequests,
      MoaiIcons.personAdd,
    ];
    // Contador naranja de la pestaña (como el del rail): sólo las
    // solicitudes recibidas; los conectados ya los dice la etiqueta de arriba.
    final badges = [0, requests.length, 0];
    final hint = switch (_panel) {
      TvFriendsDialog.friendsPanel when friends.isNotEmpty =>
        LocaleKeys.friends_tile_hint.tr(),
      TvFriendsDialog.requestsPanel when requests.isNotEmpty =>
        LocaleKeys.friends_request_hint.tr(),
      TvFriendsDialog.addPanel when _searchResults?.isNotEmpty ?? false =>
        LocaleKeys.friends_search_ok_hint.tr(),
      _ => null,
    };

    return TvDialog(
      width: 800,
      icon: MoaiIcons.watchPartyFriends,
      title: LocaleKeys.settings_tv_manage_friends.tr(),
      subtitle: LocaleKeys.friends_screen_subtitle.tr(),
      // Como el paso del PIN: cuántos están conectados.
      trailingHeader: friends.isEmpty
          ? null
          : MoaiStatusTag(
              label: LocaleKeys.friends_tag_online
                  .tr(namedArgs: {'online': '$online'})
                  .toUpperCase(),
              color: online > 0
                  ? MoaiStatusTag.soonColor
                  : MoaiStatusTag.finishedColor,
              large: true,
            ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _accordionHeight,
            child: TvAccordionRowPreview(
              panelCount: TvFriendsDialog.panelCount,
              activeIndex: _panel,
              titles: titles,
              icons: icons,
              onPanelTap: _selectPanel,
              fixedContentWidth: true,
              // Ya estamos sobre el cristal del diálogo.
              frostedPanels: false,
              tabBuilder: (index, isExpanded) => GestureDetector(
                onTap: () => _selectPanel(index),
                child: _panelTab(titles[index], icons[index], badges[index]),
              ),
              buildExpandedContent: (index, _) => Focus(
                focusNode: _panelFocus[index],
                onKeyEvent: (node, event) => _onPanelKey(index, event),
                child: switch (index) {
                  TvFriendsDialog.friendsPanel => _friendsPanel(
                    context,
                    scheme,
                    friends,
                  ),
                  TvFriendsDialog.requestsPanel => _requestsPanel(
                    context,
                    scheme,
                    requests,
                  ),
                  _ => _addPanel(context, scheme, watchParty),
                },
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            _errorBanner(context, scheme),
          ],
        ],
      ),
      actions: [
        // Qué hace OK en la lista abierta; los botones siguen a la derecha.
        if (hint != null)
          Expanded(
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MoaiText.body(
                context,
                fontSize: MoaiText.sizeCaption,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
        TvDialogButton(
          focusNode: _closeFocus,
          label: LocaleKeys.common_close.tr(),
          onPressed: () => Navigator.of(context).pop(),
          onKeyUp: _focusAboveClose,
        ),
      ],
    );
  }

  /// ←/→ que llegan al panel (de una fila o del panel vacío): panel anterior
  /// o siguiente; ↓ en un panel vacío, a Cerrar.
  KeyEventResult _onPanelKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _selectPanel(index - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _selectPanel(index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _closeFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) return KeyEventResult.handled;
    return KeyEventResult.ignored;
  }

  /// Para las extensiones de los `part` (setState es protegido).
  void _update(VoidCallback fn) => setState(fn);
}

/// Pide confirmar el rechazo de la solicitud de [request] (en el modal y en
/// la tarjeta de Solicitudes del Inicio). `true` si confirmó.
Future<bool> confirmFriendReject(
  BuildContext context,
  FriendInfo request,
) async {
  final confirmed = await showTvGeneralDialog<bool>(
    context: context,
    barrierLabel: 'FriendRejectConfirm',
    builder: (dialogContext) => _ConfirmDialog(
      icon: MoaiIcons.personRemove,
      title: LocaleKeys.friends_reject_confirm_title.tr(),
      subtitle: LocaleKeys.friends_reject_confirm_desc.tr(
        namedArgs: {'name': request.displayName},
      ),
      confirmLabel: LocaleKeys.friends_reject_button.tr(),
    ),
  );
  return confirmed == true;
}

/// El diálogo de [_TvFriendsDialogState._confirm]: dueño de sus nodos de
/// foco, así sobreviven a las reconstrucciones y se liberan al cerrarse.
class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String confirmLabel;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _cancelFocus = FocusNode(debugLabel: 'confirm_cancel');
  final _confirmFocus = FocusNode(debugLabel: 'confirm_ok');

  @override
  void dispose() {
    _cancelFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TvDialog(
      width: 460,
      icon: widget.icon,
      title: widget.title,
      subtitle: widget.subtitle,
      actions: [
        TvDialogButton(
          label: LocaleKeys.common_cancel.tr(),
          focusNode: _cancelFocus,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(false),
          onKeyRight: _confirmFocus.requestFocus,
        ),
        TvDialogButton(
          label: widget.confirmLabel,
          variant: TvDialogButtonVariant.destructive,
          focusNode: _confirmFocus,
          onPressed: () => Navigator.of(context).pop(true),
          onKeyLeft: _cancelFocus.requestFocus,
        ),
      ],
    );
  }
}
