import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/helpers/notification_helper.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';

class ClearFavoritesButton extends StatefulWidget {
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

  @override
  State<ClearFavoritesButton> createState() => _ClearFavoritesButtonState();
}

class _ClearFavoritesButtonState extends State<ClearFavoritesButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant ClearFavoritesButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode.hasFocus;
    }
  }

  void _showClearConfirmDialog(BuildContext context) {
    showTvGeneralDialog(
      context: context,
      barrierLabel: 'common_close'.tr(),
      builder: (dialogContext) {
        return _ClearConfirmDialogContent(originContext: context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isFocused = _isFocused || widget.focusNode.hasFocus;

    final Color bgColor =
        isFocused ? scheme.error : scheme.surfaceContainerHighest;
    final Color iconColor =
        isFocused ? scheme.onError : scheme.onSurfaceVariant;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft && widget.onKeyLeft != null) {
            widget.onKeyLeft!();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight && widget.onKeyRight != null) {
            widget.onKeyRight!();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowDown && widget.onKeyDown != null) {
            widget.onKeyDown!();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp && widget.onKeyUp != null) {
            widget.onKeyUp!();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            _showClearConfirmDialog(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Tooltip(
        message: 'favorites_clear_all'.tr(),
        child: GestureDetector(
          onTap: () => _showClearConfirmDialog(context),
          child: AnimatedScale(
            scale: isFocused ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: iconColor,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      icon: Icons.delete_sweep_outlined,
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
        TvDialogButton(
          focusNode: _confirmFocusNode,
          label: 'favorites_clear_all'.tr(),
          variant: TvDialogButtonVariant.destructive,
          onKeyLeft: () => _cancelFocusNode.requestFocus(),
          onPressed: () {
            Navigator.of(context).pop();
            widget.originContext.read<FavoritesProvider>().clearAllFavorites();
            NotificationHelper.showInfo(
              'favorites_cleared_snackbar'.tr(),
            );
          },
        ),
      ],
    );
  }
}
