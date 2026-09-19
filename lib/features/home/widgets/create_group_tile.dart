import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/focus/tv_layout_constants.dart';
import 'package:moai3/helpers/notification_helper.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/cards/tv_list_card_style.dart';
import 'package:moai3/widgets/tv_input/tv_input.dart';

class CreateGroupTile extends StatefulWidget {
  final FocusNode? focusNode;

  const CreateGroupTile({
    super.key,
    this.focusNode,
  });

  @override
  State<CreateGroupTile> createState() => _CreateGroupTileState();
}

class _CreateGroupTileState extends State<CreateGroupTile> {
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
            _showCreateGroupDialog(context);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () => _showCreateGroupDialog(context),
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
                    color: _isFocused
                        ? Colors.white.withValues(alpha: 0.2)
                        : scheme.onSurface.withValues(alpha: 0.08),
                    child: SizedBox(
                      width: 48,
                      height: 32,
                      child: Icon(
                        Icons.add_rounded,
                        color: itemStyle.foregroundColor,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'groups_create_tile'.tr(),
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

  void _showCreateGroupDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'common_close'.tr(),
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _CreateGroupDialogContent(tileContext: context);
      },
    );
  }
}

class _CreateGroupDialogContent extends StatefulWidget {
  final BuildContext tileContext;

  const _CreateGroupDialogContent({required this.tileContext});

  @override
  State<_CreateGroupDialogContent> createState() =>
      _CreateGroupDialogContentState();
}

class _CreateGroupDialogContentState extends State<_CreateGroupDialogContent> {
  final _textController = TextEditingController();

  late final FocusNode _textFieldFocusNode;
  late final FocusNode _cancelFocusNode;
  late final FocusNode _createFocusNode;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _textFieldFocusNode = FocusNode();
    _cancelFocusNode = FocusNode();
    _createFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFieldFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFieldFocusNode.dispose();
    _cancelFocusNode.dispose();
    _createFocusNode.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _textController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'groups_name_required'.tr());
      _textFieldFocusNode.requestFocus();
      return;
    }

    final favIds = widget.tileContext.read<FavoritesProvider>().favoriteChannelIds;
    Navigator.of(context).pop();
    try {
      await widget.tileContext.read<ChannelProvider>().createGroup(name, favIds);
      if (widget.tileContext.mounted) {
        NotificationHelper.showSuccess(
          'groups_created_success'.tr(namedArgs: {'name': name}),
        );
      }
    } catch (e) {
      if (widget.tileContext.mounted) {
        NotificationHelper.showError(
          'groups_create_error'.tr(namedArgs: {'error': '$e'}),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 64.0),
        child: Material(
          color: scheme.surfaceContainerHigh,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: SizedBox(
            width: 440,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'groups_create_title'.tr(),
                    style: MoaiText.display(
                      context,
                      color: scheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TvTextField(
                    controller: _textController,
                    focusNode: _textFieldFocusNode,
                    label: 'groups_name_label'.tr(),
                    hint: 'groups_name_hint'.tr(),
                    keyboardType: TvKeyboardType.text,
                    textInputAction: TvTextInputAction.done,
                    leadingIcon: Icons.playlist_add_rounded,
                    onFocusDown: () => _createFocusNode.requestFocus(),
                    onSubmitted: (_) => _createFocusNode.requestFocus(),
                    onChanged: (_) {
                      if (_errorText != null) {
                        setState(() => _errorText = null);
                      }
                    },
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorText!,
                      style: MoaiText.body(
                        context,
                        color: scheme.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DialogButton(
                        focusNode: _cancelFocusNode,
                        label: 'common_cancel'.tr(),
                        onPressed: () => Navigator.of(context).pop(),
                        onKeyLeft: () {},
                        onKeyRight: () => _createFocusNode.requestFocus(),
                        onKeyUp: () => _textFieldFocusNode.requestFocus(),
                      ),
                      const SizedBox(width: 8),
                      _DialogButton(
                        focusNode: _createFocusNode,
                        label: 'groups_create_confirm'.tr(),
                        isPrimary: true,
                        onKeyLeft: () => _cancelFocusNode.requestFocus(),
                        onKeyRight: () {},
                        onKeyUp: () => _textFieldFocusNode.requestFocus(),
                        onPressed: _create,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;
  final VoidCallback onKeyUp;

  const _DialogButton({
    required this.focusNode,
    required this.label,
    required this.onPressed,
    required this.onKeyLeft,
    required this.onKeyRight,
    required this.onKeyUp,
    this.isPrimary = false,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    final Color buttonColor;
    final Color textColor;
    if (widget.isPrimary) {
      buttonColor = _isFocused ? scheme.primary : scheme.primaryContainer;
      textColor = _isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;
    } else {
      buttonColor =
          _isFocused ? scheme.surfaceContainerHighest : scheme.surfaceContainer;
      textColor = _isFocused ? scheme.onSurface : scheme.onSurfaceVariant;
    }

    return Focus(
      focusNode: widget.focusNode,
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
        if (key == LogicalKeyboardKey.arrowUp) {
          widget.onKeyUp();
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
              color: _isFocused ? scheme.primary : Colors.transparent,
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

