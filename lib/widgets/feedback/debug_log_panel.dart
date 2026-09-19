import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moai3/config/player_config.dart';
import 'package:moai3/features/home/widgets/debug_log_formatters.dart';
import 'package:moai3/features/home/widgets/debug_log_widgets.dart';
import 'package:moai3/focus/tv_key_handler.dart';
import 'package:moai3/models/channel.dart';
import 'package:moai3/services/debug_log_controller.dart';
import 'package:moai3/services/playback_stats_controller.dart';
import 'package:moai3/state/channel_provider.dart';
import 'package:moai3/theme/moai_text.dart';
import 'package:provider/provider.dart';

class DebugLogPanel extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onKeyLeft;
  final VoidCallback onKeyRight;

  const DebugLogPanel({
    super.key,
    required this.focusNode,
    required this.onKeyLeft,
    required this.onKeyRight,
  });

  @override
  State<DebugLogPanel> createState() => _DebugLogPanelState();
}

class _DebugLogPanelState extends State<DebugLogPanel> {
  final ScrollController _scrollController = ScrollController();
  int _lastEntryCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottomIfNeeded(int count) {
    if (count <= _lastEntryCount) return;
    _lastEntryCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildLiveState(PlayerStatsSnapshot stats, Channel? channel, ColorScheme scheme) {
        final statusColor = debugHealthColor(stats.status, scheme);
    final dividerColor = scheme.onSurface.withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DebugSectionTitle('CONFIGURACIÓN'),
        DebugKvRow(label: 'Depuración', value: DebugLogFormatters.debugStatusLabel()),
        const DebugKvRow(label: 'Reproductor', value: PlayerConfig.modeLabel),
        DebugKvRow(label: 'Memoria', value: DebugLogFormatters.memoryLabel()),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(height: 1, color: dividerColor),
        ),
        const DebugSectionTitle('REPRODUCCIÓN'),
        DebugStatusRow(
          status: stats.status,
          color: statusColor,
          label: DebugLogFormatters.healthLabel(stats.status),
        ),
        DebugKvRow(
          label: 'Backend',
          value: DebugLogFormatters.backendLabel(stats.backend),
        ),
        if (channel != null) ...[
          DebugKvRow(label: 'Canal', value: channel.name),
          DebugKvRow(
            label: 'Tipo',
            value: DebugLogFormatters.channelTypeLabel(channel),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final timeFormat = DateFormat('HH:mm:ss');
    final dividerColor = scheme.onSurface.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.only(
        left: 7.0,
        right: 16.0,
        top: 16.0,
        bottom: 16.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 40) {
                return const SizedBox.shrink();
              }
              return Text(
                'home_panel_tv_log'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MoaiText.display(
                  context,
                  color: scheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Focus(
              focusNode: widget.focusNode,
              onKeyEvent: (node, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (TvKeyHandler.isActionKey(event.logicalKey)) {
                  return KeyEventResult.handled;
                }
                return TvKeyHandler.handleDirectional(
                  key: event.logicalKey,
                  onLeft: widget.onKeyLeft,
                  onRight: widget.onKeyRight,
                  onUp: () {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        (_scrollController.offset - 100).clamp(
                          0,
                          _scrollController.position.maxScrollExtent,
                        ),
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  onDown: () {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        (_scrollController.offset + 100).clamp(
                          0,
                          _scrollController.position.maxScrollExtent,
                        ),
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                );
              },
              child: Consumer<DebugLogController>(
                builder: (context, log, _) {
                  _scrollToBottomIfNeeded(log.entries.length);
                  return Selector2<PlaybackStatsController, ChannelProvider,
                      ({
                        PlayerStatsSnapshot stats,
                        Channel? channel,
                        })>(selector: (_, stats, channelProv) => (stats: stats.snapshot, channel: channelProv.selectedChannel),
                    builder: (context, data, _) {
                      return CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: _buildLiveState(
                              data.stats,
                              data.channel,
                              scheme,
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Container(height: 1, color: dividerColor),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: DebugSectionTitle('EVENTOS'),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 4)),
                          if (log.entries.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'debug_log_empty'.tr(),
                                  style: TextStyle(
                                    color:
                                        scheme.onSurface.withValues(alpha: 0.24),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverList.builder(
                              itemCount: log.entries.length,
                              itemBuilder: (context, index) {
                                final entry = log.entries[index];
                                return DebugEventLine(
                                  entry: entry,
                                  timeLabel: timeFormat.format(entry.time),
                                  levelColor:
                                      debugLevelColor(entry.level, scheme),
                                );
                              },
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}



