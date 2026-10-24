import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/state/watch_party_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/dialogs/tv_dialog.dart';
import 'package:moai3/widgets/feedback/moai_snackbar.dart';
import 'package:moai3/widgets/tv_input/tv_text_field.dart';
import 'package:provider/provider.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Diálogo modal para agregar un amigo mediante su código (SPEC-36 §4.3).
///
/// Presenta el prefijo 'MOAI-' fijo e inmutable, permitiendo al usuario ingresar
/// únicamente los 4 caracteres finales (alfanuméricos) en mayúsculas.
class TvAddFriendDialog extends StatefulWidget {
  const TvAddFriendDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'TvAddFriendDialog',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, anim1, anim2) => const TvAddFriendDialog(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curve),
          child: FadeTransition(opacity: curve, child: child),
        );
      },
    );
  }

  @override
  State<TvAddFriendDialog> createState() => _TvAddFriendDialogState();
}

class _TvAddFriendDialogState extends State<TvAddFriendDialog> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode(debugLabel: 'add_friend_input');
  final FocusNode _cancelFocusNode = FocusNode(debugLabel: 'add_friend_cancel');
  final FocusNode _addFocusNode = FocusNode(debugLabel: 'add_friend_submit');

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _inputFocusNode.dispose();
    _cancelFocusNode.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openTvKeyboard() async {
    final res = await TvTextField.open(
      context,
      title: LocaleKeys.friend_add_dialog_title.tr(),
      initialValue: _codeController.text,
      maxLength: 4,
      hint: LocaleKeys.friend_add_dialog_hint.tr(),
      doneLabel: LocaleKeys.friend_add_dialog_submit.tr(),
    );
    if (res != null) {
      setState(() {
        _codeController.text = res.trim().toUpperCase();
        _errorMessage = null;
      });
      _addFocusNode.requestFocus();
    }
  }

  Future<void> _handleSubmit() async {
    final rawText = _codeController.text.trim().toUpperCase();
    if (rawText.length < 4) {
      setState(() {
        _errorMessage = LocaleKeys.friend_add_dialog_error_length.tr();
      });
      _inputFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final watchParty = context.read<WatchPartyProvider>();
      await watchParty.addFriend(rawText);

      if (!mounted) return;
      Navigator.of(context).pop(true);
      MoaiSnackBar.show(
        context,
        message: LocaleKeys.friend_add_dialog_success.tr(),
        icon: MoaiIcons.checkCircle,
      );
    } catch (e) {
      if (!mounted) return;
      final rawError = e.toString().replaceAll('Exception: ', '').trim();
      final translatedError = (rawError.startsWith('friend_add_') || rawError.startsWith('friends_'))
          ? rawError.tr()
          : LocaleKeys.friend_add_error_generic.tr();
      setState(() {
        _isSubmitting = false;
        _errorMessage = translatedError;
      });
      _inputFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TvDialog(
      icon: MoaiIcons.personAdd,
      title: LocaleKeys.friend_add_dialog_title.tr(),
      subtitle: LocaleKeys.friend_add_dialog_subtitle.tr(),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Focus(
            focusNode: _inputFocusNode,
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                _cancelFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.select) {
                _openTvKeyboard();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              onTap: _openTvKeyboard,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _errorMessage != null
                        ? scheme.error
                        : (_inputFocusNode.hasFocus
                            ? scheme.primary
                            : scheme.outlineVariant.withValues(alpha: 0.4)),
                    width: _inputFocusNode.hasFocus ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Prefijo bloqueado e inmutable
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'MOAI-',
                        style: MoaiText.display(
                          context,
                          fontSize: 20,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Campo para los 4 caracteres
                    Expanded(
                      child: Text(
                        _codeController.text.isEmpty
                            ? LocaleKeys.friend_add_dialog_hint.tr()
                            : _codeController.text,
                        style: MoaiText.display(
                          context,
                          fontSize: 22,
                          letterSpacing: 6.0,
                          color: _codeController.text.isEmpty
                              ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      MoaiIcons.keyboard,
                      size: MoaiIconSizes.md,
                      color: _inputFocusNode.hasFocus
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(MoaiIcons.error, size: MoaiIconSizes.sm, color: scheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: MoaiText.body(
                      context,
                      fontSize: 13,
                      color: scheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TvDialogButton(
          label: LocaleKeys.common_cancel.tr(),
          focusNode: _cancelFocusNode,
          onPressed: () => Navigator.of(context).pop(false),
          onKeyRight: _addFocusNode.requestFocus,
          onKeyUp: _inputFocusNode.requestFocus,
        ),
        TvDialogButton(
          label: _isSubmitting ? LocaleKeys.friend_add_dialog_verifying.tr() : LocaleKeys.friend_add_dialog_submit.tr(),
          variant: TvDialogButtonVariant.primary,
          focusNode: _addFocusNode,
          onPressed: _isSubmitting ? () {} : _handleSubmit,
          onKeyLeft: _cancelFocusNode.requestFocus,
          onKeyUp: _inputFocusNode.requestFocus,
        ),
      ],
    );
  }
}
