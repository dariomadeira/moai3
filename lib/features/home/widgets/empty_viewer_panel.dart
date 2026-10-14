import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/theme/moai_icons.dart';

/// Panel mostrado en el área derecha cuando no hay canal activo / seleccionado.
class EmptyViewerPanel extends StatelessWidget {
  final FocusNode focusNode;
  final bool hasChannels;
  final VoidCallback onReturnToPanel;
  final VoidCallback onKeyUp;

  const EmptyViewerPanel({
    super.key,
    required this.focusNode,
    required this.hasChannels,
    required this.onReturnToPanel,
    required this.onKeyUp,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowRight ||
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space) {
          onReturnToPanel();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          onKeyUp();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: onReturnToPanel,
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            final baseColor = scheme.surface;
            final endColor = Color.alphaBlend(
              scheme.onSurface.withValues(alpha: 0.05),
              baseColor,
            );
            final borderColor = isFocused
                ? scheme.primary
                : scheme.outlineVariant.withValues(alpha: 0.48);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomRight,
                  end: Alignment.topLeft,
                  colors: [baseColor, baseColor, endColor],
                  stops: const [0.0, 0.62, 1.0],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor,
                  width: isFocused ? 1.0 : 0.6,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: isFocused
                              ? scheme.primary.withValues(alpha: 0.15)
                              : scheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          MoaiIcons.liveTvOutlined,
                          size: 40,
                          color: isFocused
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        hasChannels
                            ? 'home_tv_viewer_empty'.tr()
                            : 'home_tv_viewer_no_channels'.tr(),
                        textAlign: TextAlign.center,
                        style: MoaiText.display(
                          context,
                          color: scheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasChannels
                            ? 'home_tv_viewer_empty_desc'.tr()
                            : 'home_tv_viewer_no_channels_desc'.tr(),
                        textAlign: TextAlign.center,
                        style: MoaiText.body(
                          context,
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
