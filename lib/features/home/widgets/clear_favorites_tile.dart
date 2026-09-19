import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/helpers/notification_helper.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_list_card_style.dart';

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
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'common_close'.tr(),
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
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

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 80.0),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'favorites_clear_title'.tr(),
                  style: MoaiText.display(
                    context,
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'favorites_clear_confirm_body'.tr(),
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ConfirmDialogButton(
                      focusNode: _cancelFocusNode,
                      label: 'common_cancel'.tr(),
                      onPressed: () => Navigator.of(context).pop(),
                      onKeyLeft: () {},
                      onKeyRight: () => _confirmFocusNode.requestFocus(),
                    ),
                    const SizedBox(width: 10),
                    _ConfirmDialogButton(
                      focusNode: _confirmFocusNode,
                      label: 'favorites_clear_all'.tr(),
                      isDestructive: true,
                      onKeyLeft: () => _cancelFocusNode.requestFocus(),
                      onKeyRight: () {},
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.tileContext.read<FavoritesProvider>().clearAllFavorites();
                        NotificationHelper.showInfo(
                          'favorites_cleared_snackbar'.tr(),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmDialogButton extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;

  const _ConfirmDialogButton({
    required this.focusNode,
    required this.label,
    required this.onPressed,
    required this.onKeyLeft,
    required this.onKeyRight,
    this.isDestructive = false,
  });

  @override
  State<_ConfirmDialogButton> createState() => _ConfirmDialogButtonState();
}

class _ConfirmDialogButtonState extends State<_ConfirmDialogButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    Color buttonColor;
    Color textColor;
    if (widget.isDestructive) {
      buttonColor = _isFocused ? scheme.error : scheme.errorContainer;
      textColor = _isFocused ? scheme.onError : scheme.onErrorContainer;
    } else {
      buttonColor =
          _isFocused ? scheme.surfaceContainerHighest : scheme.surfaceContainer;
      textColor = _isFocused ? scheme.onSurface : scheme.onSurfaceVariant;
    }

    return Focus(
      focusNode: widget.focusNode,
      autofocus: !widget.isDestructive,
      onFocusChange: (focus) => setState(() => _isFocused = focus),
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.select) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          widget.onKeyLeft();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          widget.onKeyRight();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFocused
                  ? (widget.isDestructive ? scheme.error : scheme.primary)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            widget.label,
            style: MoaiText.body(
              context,
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

