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
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
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
    showTvGeneralDialog(
      context: context,
      barrierLabel: 'common_close'.tr(),
      builder: (dialogContext) {
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

    return TvDialog(
      icon: Icons.bookmark_add_rounded,
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

