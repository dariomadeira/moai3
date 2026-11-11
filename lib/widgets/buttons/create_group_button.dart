import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/state/favorites_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/tv_input/tv_input.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/buttons/tv_glass_icon_pill.dart';

/// Crea un marcador.
class CreateGroupButton extends StatelessWidget {
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

  void _showCreateDialog(BuildContext context) {
    showTvGeneralDialog(
      context: context,
      barrierLabel: LocaleKeys.common_close.tr(),
      builder: (dialogContext) {
        return _CreateGroupDialogContent(originContext: context);
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
    icon: MoaiIcons.tvFavoritesAdd,
    tooltip: LocaleKeys.common_create.tr(),
    onPressed: () => _showCreateDialog(context),
  );
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
      setState(() => _errorText = LocaleKeys.groups_name_required.tr());
      _textFieldFocusNode.requestFocus();
      return;
    }

    final favIds = widget.originContext
        .read<FavoritesProvider>()
        .favoriteChannelIds;
    Navigator.of(context).pop();
    try {
      await widget.originContext.read<ChannelProvider>().createGroup(
        name,
        favIds,
      );
      if (widget.originContext.mounted) {
        MoaiSnackBar.show(
          widget.originContext,
          message: LocaleKeys.groups_created_success.tr(
            namedArgs: {'name': name},
          ),
          icon: MoaiIcons.groupCreate,
        );
      }
    } catch (e) {
      if (widget.originContext.mounted) {
        MoaiSnackBar.show(
          widget.originContext,
          message: LocaleKeys.groups_create_error.tr(
            namedArgs: {'error': '$e'},
          ),
          icon: MoaiIcons.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return TvDialog(
      icon: MoaiIcons.tvGroupCreateDialogTitle,
      title: LocaleKeys.groups_create_title.tr(),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TvTextField(
            controller: _textController,
            focusNode: _textFieldFocusNode,
            label: LocaleKeys.groups_name_label.tr(),
            hint: LocaleKeys.groups_name_hint.tr(),
            leadingIcon: MoaiIcons.tvGroupCreateDialogInput,
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
          label: LocaleKeys.common_cancel.tr(),
          onPressed: () => Navigator.of(context).pop(),
          onKeyRight: () => _createFocusNode.requestFocus(),
          onKeyUp: () => _textFieldFocusNode.requestFocus(),
        ),
        TvDialogButton(
          focusNode: _createFocusNode,
          label: LocaleKeys.common_create.tr(),
          variant: TvDialogButtonVariant.primary,
          onKeyLeft: () => _cancelFocusNode.requestFocus(),
          onKeyUp: () => _textFieldFocusNode.requestFocus(),
          onPressed: _create,
        ),
      ],
    );
  }
}
