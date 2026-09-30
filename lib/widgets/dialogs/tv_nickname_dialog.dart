import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/tv_input/tv_keyboard_type.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';

/// Diálogo TV para configurar o cambiar el apodo (Nickname) del usuario.
///
/// Cumple con las pautas de accesibilidad para Android TV y D-Pad:
/// - Reutiliza [TvDialog], [TvTextField] y [TvDialogButton].
/// - Valida que el apodo nunca quede vacío (`nickname_dialog_error_empty`).
/// - En modo obligatorio ([isMandatory] = true), no es dismissible por tap exterior.
class TvNicknameDialog extends StatefulWidget {
  final String? initialNickname;
  final bool isMandatory;

  const TvNicknameDialog({
    super.key,
    this.initialNickname,
    this.isMandatory = false,
  });

  /// Muestra el modal de apodo y devuelve el nickname ingresado o null si se canceló.
  static Future<String?> show(
    BuildContext context, {
    String? initialNickname,
    bool isMandatory = false,
  }) {
    return showTvGeneralDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'TvNicknameDialog',
      builder: (dialogContext) {
        return TvNicknameDialog(
          initialNickname: initialNickname,
          isMandatory: isMandatory,
        );
      },
    );
  }

  @override
  State<TvNicknameDialog> createState() => _TvNicknameDialogState();
}

class _TvNicknameDialogState extends State<TvNicknameDialog> {
  late final TextEditingController _textController;
  late final FocusNode _textFieldFocusNode;
  late final FocusNode _cancelFocusNode;
  late final FocusNode _saveFocusNode;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialNickname ?? '');
    _textFieldFocusNode = FocusNode(debugLabel: 'nickname_text_field');
    _cancelFocusNode = FocusNode(debugLabel: 'nickname_cancel');
    _saveFocusNode = FocusNode(debugLabel: 'nickname_save');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _textFieldFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFieldFocusNode.dispose();
    _cancelFocusNode.dispose();
    _saveFocusNode.dispose();
    super.dispose();
  }

  void _save() {
    final name = _textController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'nickname_dialog_error_empty'.tr());
      _textFieldFocusNode.requestFocus();
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final title = widget.isMandatory
        ? 'nickname_dialog_title_setup'.tr()
        : 'nickname_dialog_title_edit'.tr();
    final subtitle = widget.isMandatory
        ? 'nickname_dialog_subtitle_setup'.tr()
        : 'nickname_dialog_subtitle_edit'.tr();

    return TvDialog(
      width: 640,
      icon: Icons.badge_outlined,
      title: title,
      subtitle: subtitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TvTextField(
            controller: _textController,
            focusNode: _textFieldFocusNode,
            label: 'nickname_dialog_label'.tr(),
            hint: 'nickname_dialog_hint'.tr(),
            keyboardType: TvKeyboardType.text,
            textInputAction: TvTextInputAction.done,
            leadingIcon: Icons.person_outline,
            maxLength: 30,
            onFocusDown: () => _saveFocusNode.requestFocus(),
            onSubmitted: (_) => _saveFocusNode.requestFocus(),
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
          onPressed: () => Navigator.of(context).pop(null),
          onKeyRight: () => _saveFocusNode.requestFocus(),
          onKeyUp: () => _textFieldFocusNode.requestFocus(),
        ),
        const SizedBox(width: 12),
        TvDialogButton(
          focusNode: _saveFocusNode,
          label: 'nickname_dialog_confirm'.tr(),
          variant: TvDialogButtonVariant.primary,
          onKeyLeft: () => _cancelFocusNode.requestFocus(),
          onKeyUp: () => _textFieldFocusNode.requestFocus(),
          onPressed: _save,
        ),
      ],
    );
  }
}
