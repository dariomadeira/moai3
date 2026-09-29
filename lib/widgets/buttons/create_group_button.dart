import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/tv_input/tv_input.dart';

class CreateGroupButton extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback? onKeyLeft;
  final VoidCallback? onKeyRight;
  final VoidCallback? onKeyUp;
  final VoidCallback? onKeyDown;

  const CreateGroupButton({
    super.key,
    required this.focusNode,
    this.onKeyLeft,
    this.onKeyRight,
    this.onKeyUp,
    this.onKeyDown,
  });

  @override
  State<CreateGroupButton> createState() => _CreateGroupButtonState();
}

class _CreateGroupButtonState extends State<CreateGroupButton> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _isFocused = widget.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant CreateGroupButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _isFocused = widget.focusNode.hasFocus;
    }
  }

  void _showCreateDialog(BuildContext context) {
    showTvGeneralDialog(
      context: context,
      barrierLabel: 'common_close'.tr(),
      builder: (dialogContext) {
        return _CreateGroupDialogContent(originContext: context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isFocused = _isFocused || widget.focusNode.hasFocus;

    final Color bgColor =
        isFocused ? scheme.primary : scheme.surfaceContainerHighest;
    final Color iconColor =
        isFocused ? scheme.onPrimary : scheme.onSurfaceVariant;

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
            _showCreateDialog(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Tooltip(
        message: 'groups_create_tile'.tr(),
        child: GestureDetector(
          onTap: () => _showCreateDialog(context),
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
                  Icons.add_rounded,
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

class _CreateGroupDialogContent extends StatefulWidget {
  final BuildContext originContext;

  const _CreateGroupDialogContent({required this.originContext});

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

    final favIds =
        widget.originContext.read<FavoritesProvider>().favoriteChannelIds;
    Navigator.of(context).pop();
    try {
      await widget.originContext.read<ChannelProvider>().createGroup(name, favIds);
      if (widget.originContext.mounted) {
        MoaiSnackBar.show(
          widget.originContext,
          message: 'groups_created_success'.tr(namedArgs: {'name': name}),
          icon: Icons.bookmark_add_outlined,
        );
      }
    } catch (e) {
      if (widget.originContext.mounted) {
        MoaiSnackBar.show(
          widget.originContext,
          message: 'groups_create_error'.tr(namedArgs: {'error': '$e'}),
          icon: Icons.error_outline,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return TvDialog(
      icon: Icons.bookmark_add_outlined,
      title: 'groups_create_title'.tr(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TvTextField(
            controller: _textController,
            focusNode: _textFieldFocusNode,
            label: 'groups_name_label'.tr(),
            hint: 'groups_name_hint'.tr(),
            keyboardType: TvKeyboardType.text,
            textInputAction: TvTextInputAction.done,
            leadingIcon: Icons.playlist_add_outlined,
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
        ],
      ),
      actions: [
        TvDialogButton(
          focusNode: _cancelFocusNode,
          label: 'common_cancel'.tr(),
          variant: TvDialogButtonVariant.neutral,
          onPressed: () => Navigator.of(context).pop(),
          onKeyRight: () => _createFocusNode.requestFocus(),
          onKeyUp: () => _textFieldFocusNode.requestFocus(),
        ),
        const SizedBox(width: 12),
        TvDialogButton(
          focusNode: _createFocusNode,
          label: 'groups_create_confirm'.tr(),
          variant: TvDialogButtonVariant.primary,
          onKeyLeft: () => _cancelFocusNode.requestFocus(),
          onKeyUp: () => _textFieldFocusNode.requestFocus(),
          onPressed: _create,
        ),
      ],
    );
  }
}
