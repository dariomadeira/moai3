import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/widgets/feedback/notification_helper.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/buttons/tv_glass_icon_pill.dart';

/// Limpia los favoritos, con confirmación.
class ClearFavoritesButton extends StatelessWidget {
  final FocusNode focusNode;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const ClearFavoritesButton({
    super.key,
    required this.focusNode,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  void _showClearConfirmDialog(BuildContext context) {
    showTvGeneralDialog(
      context: context,
      barrierLabel: LocaleKeys.common_close.tr(),
      builder: (dialogContext) {
        return _ClearConfirmDialogContent(originContext: context);
      },
    );
  }

  @override
  Widget build(BuildContext context) => TvGlassIconPill(
    focusNode: focusNode,
    onKeyLeft: onKeyLeft,
    onKeyRight: onKeyRight,
    onKeyUp: onKeyUp,
    onKeyDown: onKeyDown,
    icon: MoaiIcons.tvFavoritesClear,
    tooltip: LocaleKeys.favorites_clear_all.tr(),
    onPressed: () => _showClearConfirmDialog(context),
  );
}

class _ClearConfirmDialogContent extends StatefulWidget {
  final BuildContext originContext;

  const _ClearConfirmDialogContent({required this.originContext});

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
      icon: MoaiIcons.delete,
      iconBgColor: scheme.errorContainer,
      iconColor: scheme.onErrorContainer,
      title: LocaleKeys.favorites_clear_title.tr(),
      content: Text(
        LocaleKeys.favorites_clear_confirm_body.tr(),
        style: MoaiText.body(
          context,
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
      actions: [
        TvDialogButton(
          focusNode: _cancelFocusNode,
          label: LocaleKeys.common_cancel.tr(),
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(),
          onKeyRight: () => _confirmFocusNode.requestFocus(),
        ),
        TvDialogButton(
          focusNode: _confirmFocusNode,
          label: LocaleKeys.favorites_clear_all.tr(),
          variant: TvDialogButtonVariant.destructive,
          onKeyLeft: () => _cancelFocusNode.requestFocus(),
          onPressed: () {
            Navigator.of(context).pop();
            widget.originContext.read<FavoritesProvider>().clearAllFavorites();
            NotificationHelper.showInfo(
              LocaleKeys.favorites_cleared_snackbar.tr(),
            );
          },
        ),
      ],
    );
  }
}
