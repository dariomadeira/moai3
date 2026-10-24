part of '../tv_voice_test_dialog.dart';

/// Tarjeta principal por estado (inicial, grabando, grabado), ondas, consejos y pie de hardware.
extension _TvVoiceTestViews on _TvVoiceTestDialogState {
  Widget _buildTipBanner(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            MoaiIcons.tip,
            size: MoaiIconSizes.md,
            color: scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              LocaleKeys.mic_test_tip.tr(),
              style: MoaiText.body(
                context,
                fontSize: 12,
                color: scheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(ColorScheme scheme) {
    final baseColor = scheme.surface.withValues(alpha: 0.8);
    final endColor = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: 0.05),
      baseColor,
    );
    final borderColor = scheme.outlineVariant.withValues(alpha: 0.2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
        ),
      ),
      child: Column(
        children: [
          if (_isRecording)
            _buildRecordingState(scheme)
          else if (_recordedPath != null)
            _buildRecordedState(scheme)
          else
            _buildIdleState(scheme),
        ],
      ),
    );
  }

  Widget _buildIdleState(ColorScheme scheme) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            MoaiIcons.mic,
            size: MoaiIconSizes.xl,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          LocaleKeys.mic_test_ready_hint.tr(),
          style: MoaiText.body(
            context,
            fontSize: 13,
            color: scheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          focusNode: _recordFocus,
          icon: MoaiIcons.record,
          label: LocaleKeys.mic_test_btn_record.tr(),
          isPrimary: true,
          onPressed: _startRecording,
          onKeyDown: _closeFocus.requestFocus,
        ),
      ],
    );
  }

  Widget _buildRecordingState(ColorScheme scheme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: scheme.error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '0:0$_recordSeconds / 0:06',
              style: MoaiText.display(
                context,
                fontSize: 20,
                color: scheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildWaveVisualizer(scheme, color: scheme.error),
        const SizedBox(height: 10),
        Text(
          LocaleKeys.mic_test_recording_active.tr(),
          style: MoaiText.body(
            context,
            fontSize: 12.5,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildActionButton(
          focusNode: _recordFocus,
          icon: MoaiIcons.stopCircle,
          label: LocaleKeys.mic_test_btn_stop.tr(
            namedArgs: {'seconds': '$_recordSeconds'},
          ),
          customBg: scheme.error,
          customFg: scheme.onError,
          onPressed: _stopRecording,
          onKeyDown: _closeFocus.requestFocus,
        ),
      ],
    );
  }

  Widget _buildRecordedState(ColorScheme scheme) {
    final isAudioValid = _recordedBytes > 1024;
    final kbStr = (_recordedBytes / 1024).toStringAsFixed(1);

    return Column(
      children: [
        if (isAudioValid) ...[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  LocaleKeys.mic_test_badge_ready.tr(),
                  style: MoaiText.body(
                    context,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      MoaiIcons.volume,
                      size: MoaiIconSizes.sm,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      LocaleKeys.mic_test_badge_amplified.tr(),
                      style: MoaiText.body(
                        context,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isPlaying) ...[
            _buildWaveVisualizer(scheme, color: scheme.tertiary),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.mic_test_playing_active.tr(),
              style: MoaiText.body(
                context,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
          ] else ...[
            Text(
              LocaleKeys.mic_test_success_desc.tr(namedArgs: {'kb': kbStr}),
              style: MoaiText.body(
                context,
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ] else ...[
          Icon(MoaiIcons.warning, size: MoaiIconSizes.xxl, color: scheme.error),
          const SizedBox(height: 6),
          Text(
            LocaleKeys.mic_test_empty_desc.tr(
              namedArgs: {'bytes': '$_recordedBytes'},
            ),
            style: MoaiText.body(
              context,
              fontSize: 12,
              color: scheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isAudioValid) ...[
              Expanded(
                child: _buildActionButton(
                  focusNode: _playFocus,
                  icon: _isPlaying ? MoaiIcons.stop : MoaiIcons.volume,
                  label: _isPlaying
                      ? LocaleKeys.mic_test_btn_stop_play.tr()
                      : LocaleKeys.mic_test_btn_play.tr(),
                  isPrimary: true,
                  customBg: _isPlaying ? scheme.tertiary : null,
                  customFg: _isPlaying ? scheme.onTertiary : null,
                  onPressed: _togglePlayback,
                  onKeyRight: _rerecordFocus.requestFocus,
                  onKeyDown: _closeFocus.requestFocus,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: _buildActionButton(
                focusNode: _rerecordFocus,
                icon: MoaiIcons.refresh,
                label: LocaleKeys.mic_test_btn_rerecord.tr(),
                isPrimary: !isAudioValid,
                onPressed: _startRecording,
                onKeyLeft: () {
                  if (isAudioValid) _playFocus.requestFocus();
                },
                onKeyDown: _closeFocus.requestFocus,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWaveVisualizer(ColorScheme scheme, {required Color color}) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        final progress = _waveController.value;
        const barHeights = [14.0, 26.0, 36.0, 22.0, 32.0, 18.0, 28.0];

        return SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(barHeights.length, (index) {
              final offset = (index * 0.18) % 1.0;
              final factor = ((progress + offset) % 1.0);
              final dynamicHeight =
                  (barHeights[index] * (0.4 + 0.6 * factor)).clamp(8.0, 38.0);

              return Container(
                width: 5,
                height: dynamicHeight,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.8 + 0.2 * factor),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildHardwareFooter(ColorScheme scheme) {
    final devNames = _devices
        .map((d) => d['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final infoText = devNames.isNotEmpty
        ? devNames.join(', ')
        : LocaleKeys.mic_test_no_devices.tr();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            MoaiIcons.tv,
            size: MoaiIconSizes.sm,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              LocaleKeys.mic_test_devices_header.tr(
                namedArgs: {'info': infoText},
              ),
              style: MoaiText.body(
                context,
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
    Color? customBg,
    Color? customFg,
    VoidCallback? onKeyLeft,
    VoidCallback? onKeyRight,
    VoidCallback? onKeyUp,
    VoidCallback? onKeyDown,
  }) {
    return Focus(
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        if (TvKeyHandler.isActionKey(key)) {
          onPressed();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft && onKeyLeft != null) {
          onKeyLeft();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight && onKeyRight != null) {
          onKeyRight();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp && onKeyUp != null) {
          onKeyUp();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown && onKeyDown != null) {
          onKeyDown();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          final scheme = Theme.of(context).colorScheme;

          Color bg;
          Color fg;

          if (customBg != null) {
            if (customBg == scheme.error) {
              bg = isFocused ? scheme.error : scheme.errorContainer;
              fg = isFocused ? scheme.onError : scheme.onErrorContainer;
            } else if (customBg == scheme.tertiary) {
              bg = isFocused ? scheme.tertiary : scheme.tertiaryContainer;
              fg = isFocused ? scheme.onTertiary : scheme.onTertiaryContainer;
            } else {
              bg = isFocused ? customBg : scheme.surfaceContainerHigh;
              fg = customFg ?? (isFocused ? Colors.white : scheme.onSurfaceVariant);
            }
          } else if (isPrimary) {
            bg = isFocused ? scheme.primary : scheme.primaryContainer;
            fg = isFocused ? scheme.onPrimary : scheme.onPrimaryContainer;
          } else {
            bg = isFocused
                ? scheme.surfaceContainerHighest
                : scheme.surfaceContainerHigh;
            fg = isFocused ? scheme.onSurface : scheme.onSurfaceVariant;
          }

          return GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: MoaiIconSizes.md, color: fg),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: MoaiText.body(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: fg,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
