import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';
import 'package:moai3/widgets/tv_common/moai_glass.dart';

/// Estado de error compacto del visor TV.
class ViewerErrorDisplay extends StatelessWidget {
  final String errorMessage;

  const ViewerErrorDisplay({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: moaiVideoGlassDecoration(radius: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  MoaiIcons.error,
                  size: MoaiIconSizes.xl,
                  color: Color(0xFFF87171), // se lee sobre el cristal oscuro
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.body(
                    context,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  LocaleKeys.player_error_retry_hint.tr(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MoaiText.body(
                    context,
                    color: const Color(0xCCFFFFFF),
                    fontSize: MoaiText.sizeCaption,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
