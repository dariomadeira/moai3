import 'package:flutter/material.dart';
import 'package:moai3/services/debug_log_controller.dart';
import 'package:moai3/services/playback_stats_controller.dart';
import 'package:moai3/theme/moai_text.dart';

class DebugKvRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final double labelWidth;

  const DebugKvRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.labelWidth = 88,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final labelStyle = TextStyle(
      color: scheme.onSurface.withValues(alpha: 0.38),
      fontSize: 11,
      height: 1.35,
    );
    final valueStyle = TextStyle(
      color: valueColor ?? scheme.onSurface,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 1.35,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 120) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DebugSectionTitle extends StatelessWidget {
  final String title;

  const DebugSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        title,
        style: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.38),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class DebugStatusRow extends StatelessWidget {
  final PlaybackHealth status;
  final Color color;
  final String label;

  const DebugStatusRow({
    super.key,
    required this.status,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DebugEventLine extends StatelessWidget {
  final DebugLogEntry entry;
  final String timeLabel;
  final Color levelColor;

  const DebugEventLine({
    super.key,
    required this.entry,
    required this.timeLabel,
    required this.levelColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            timeLabel,
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.24),
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: levelColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.message,
              style: TextStyle(color: levelColor, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

Color debugLevelColor(DebugLogLevel level, ColorScheme scheme) {
  switch (level) {
    case DebugLogLevel.info:
      return scheme.primary;
    case DebugLogLevel.warn:
      return scheme.secondary;
    case DebugLogLevel.error:
      return scheme.error;
  }
}

Color debugHealthColor(PlaybackHealth status, ColorScheme scheme) {
  switch (status) {
    case PlaybackHealth.playing:
      return scheme.primary;
    case PlaybackHealth.buffering:
    case PlaybackHealth.reconnecting:
      return scheme.secondary;
    case PlaybackHealth.error:
      return scheme.error;
    case PlaybackHealth.idle:
      return scheme.secondary.withValues(alpha: 0.5);
  }
}

