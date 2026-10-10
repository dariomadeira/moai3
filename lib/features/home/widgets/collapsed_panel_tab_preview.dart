import 'package:flutter/material.dart';
import 'package:moai3/theme/moai_text.dart';

/// Tab vertical del acordeón (título rotado + icono).
class CollapsedPanelTabPreview extends StatelessWidget {
  final String title;
  final dynamic icon;
  final bool hasFocus;

  const CollapsedPanelTabPreview({
    super.key,
    required this.title,
    required this.icon,
    this.hasFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final textColor =
        hasFocus ? scheme.primary : scheme.onSurface.withValues(alpha: 0.7);
    final iconColor = hasFocus
        ? scheme.primary
        : scheme.onSurfaceVariant.withValues(alpha: 0.85);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          RotatedBox(
            quarterTurns: 3,
            child: Text(
              title,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
              style: MoaiText.display(
                context,
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          icon is Widget
              ? IconTheme(
                  data: IconThemeData(size: 20, color: iconColor),
                  child: icon as Widget,
                )
              : Icon(icon as IconData, size: 20, color: iconColor),
        ],
      ),
    );
  }
}
