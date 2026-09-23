import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/helpers/notification_helper.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_list_card_style.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';

class ClearFavoritesTile extends StatefulWidget {
  final FocusNode? focusNode;

  const ClearFavoritesTile({
    super.key,
    this.focusNode,
  });

  @override
  State<ClearFavoritesTile> createState() => _ClearFavoritesTileState();
}

class _ClearFavoritesTileState extends State<ClearFavoritesTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final itemStyle = TvListCardStyle.resolve(
      scheme: scheme,
      focused: _isFocused,
      selected: false,
    );

    return SizedBox(
      width: TvLayoutConstants.viewerFavoriteTileWidth,
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (focus) => setState(() => _isFocused = focus),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            _showClearConfirmDialog(context);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () => _showClearConfirmDialog(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: itemStyle.backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ColoredBox(
                    color: Colors.red.withValues(alpha: 0.15),
                    child: SizedBox(
                      width: 48,
                      height: 32,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: _isFocused ? scheme.onPrimary : Colors.redAccent,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'favorites_clear_all'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: MoaiText.body(
                    context,
                    color: itemStyle.foregroundColor,
                    fontSize: 11,
                    fontWeight: itemStyle.fontWeight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClearConfirmDialog(BuildContext context) {
    showTvGeneralDialog(
      context: context,
      barrierLabel: 'common_close'.tr(),
      builder: (dialogContext) {
        return _ClearConfirmDialogContent(tileContext: context);
      },
    );
  }
}

class _ClearConfirmDialogContent extends StatefulWidget {
  final BuildContext tileContext;

  const _ClearConfirmDialogContent({required this.tileContext});

  @override
  State<_ClearConfirmDialogContent> createState() =>
      _ClearConfirmDialogContentState();
}

class _ClearConfirmDialogContentState
    extends State<_ClearConfirmDialogContent> {
  late final FocusNode _cancelFocusNode;
  late final FocusNode _confirmFocusNode;

  @override
  void initState() {
    super.initState();
    _cancelFocusNode = FocusNode();
    _confirmFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _cancelFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return TvDialog(
      icon: Icons.delete_sweep_rounded,
      iconBgColor: scheme.errorContainer,
      iconColor: scheme.onErrorContainer,
      title: 'favorites_clear_title'.tr(),
      content: Text(
        'favorites_clear_confirm_body'.tr(),
        style: MoaiText.body(
          context,
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
      actions: [
        TvDialogButton(
          focusNode: _cancelFocusNode,
          label: 'common_cancel'.tr(),
          variant: TvDialogButtonVariant.neutral,
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          onKeyRight: () => _confirmFocusNode.requestFocus(),
        ),
        const SizedBox(width: 12),
        TvDialogButton(
          focusNode: _confirmFocusNode,
          label: 'favorites_clear_all'.tr(),
          variant: TvDialogButtonVariant.destructive,
          onKeyLeft: () => _cancelFocusNode.requestFocus(),
          onPressed: () {
            Navigator.of(context).pop();
            widget.tileContext.read<FavoritesProvider>().clearAllFavorites();
            NotificationHelper.showInfo(
              'favorites_cleared_snackbar'.tr(),
            );
          },
        ),
      ],
    );
  }
}

