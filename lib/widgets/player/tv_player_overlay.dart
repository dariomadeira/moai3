import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:moai3/features/home/controllers/player_overlay_controller.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:moai3/widgets/player/tv_viewer.dart';
import 'package:provider/provider.dart';

/// Overlay que posiciona [TvViewer] sobre el ancla 16:9 (o fullscreen).
class TvPlayerOverlay extends StatelessWidget {
  final Channel? channel;
  final PlayerOverlayController overlayController;
  final FocusNode focusNode;
  final VoidCallback? onRequestListFocus;
  final VoidCallback? onRequestUpFocus;
  final VoidCallback? onExitFullScreen;

  const TvPlayerOverlay({
    super.key,
    required this.channel,
    required this.overlayController,
    required this.focusNode,
    this.onRequestListFocus,
    this.onRequestUpFocus,
    this.onExitFullScreen,
  });

  static Rect _toStackLocal(BuildContext context, Rect globalRect) {
    final stack = context.findAncestorRenderObjectOfType<RenderStack>();
    if (stack == null || !stack.hasSize) return globalRect;
    final topLeft = stack.globalToLocal(globalRect.topLeft);
    return topLeft & globalRect.size;
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ChannelProvider, ({
      int reloadKey,
      int serverSkipKey,
    })>(
      selector: (_, state) => (
        reloadKey: state.reloadKey,
        serverSkipKey: state.serverSkipKey,
      ),
      builder: (context, data, _) {
        return ListenableBuilder(
          listenable: overlayController,
          builder: (context, _) {
            if (channel == null) return const SizedBox.shrink();

            final size = MediaQuery.sizeOf(context);
            final Rect globalRect = overlayController.isFullScreen
                ? Rect.fromLTWH(0, 0, size.width, size.height)
                : overlayController.smallPlayerRect;

            if (globalRect.width <= 0 || globalRect.height <= 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                overlayController.updatePlaceholderRect(retryIfInvalid: true);
              });
              return const SizedBox.shrink();
            }

            final rect = _toStackLocal(context, globalRect);

            return Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              height: rect.height,
              child: RepaintBoundary(
                child: TvViewer(
                  key: const ValueKey('viewer-exoplayer'),
                  channel: channel,
                  isFullScreen: overlayController.isFullScreen,
                  reloadKey: data.reloadKey,
                  serverSkipKey: data.serverSkipKey,
                  onFullScreenChanged: (full) {
                    overlayController.setFullScreen(full);
                    if (!full) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (focusNode.canRequestFocus) focusNode.requestFocus();
                      });
                      onExitFullScreen?.call();
                    }
                  },
                  onRequestListFocus: onRequestListFocus,
                  onRequestUpFocus: onRequestUpFocus,
                  onErrorStateChanged: (hasError) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      context.read<ChannelProvider>().setChannelError(hasError);
                    });
                  },
                  focusNode: focusNode,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Reserva el hueco 16:9 y reporta bounds vía [PlayerOverlayController].
class TvPlayerLayoutAnchor extends StatefulWidget {
  final PlayerOverlayController overlayController;

  const TvPlayerLayoutAnchor({
    super.key,
    required this.overlayController,
  });

  @override
  State<TvPlayerLayoutAnchor> createState() => _TvPlayerLayoutAnchorState();
}

class _TvPlayerLayoutAnchorState extends State<TvPlayerLayoutAnchor> {
  @override
  void initState() {
    super.initState();
    _scheduleBoundsUpdate();
  }

  @override
  void didUpdateWidget(covariant TvPlayerLayoutAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleBoundsUpdate();
  }

  void _scheduleBoundsUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.overlayController.updatePlaceholderRect(retryIfInvalid: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return AspectRatio(
      key: widget.overlayController.placeholderKey,
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
