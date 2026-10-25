part of '../tv_voice_test_dialog.dart';

/// Escenario central por estado (listo, grabando, grabado): orbe con anillos,
/// onda de audio, progreso y controles; más el pie con consejo y hardware.
extension _TvVoiceTestViews on _TvVoiceTestDialogState {
  static const _maxSeconds = 6;

  /// Escenario: pozo de cristal con el orbe, el estado y los botones.
  Widget _buildMainCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: moaiGlassWellDecoration(scheme),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
        _buildOrb(scheme, color: scheme.primary, icon: MoaiIcons.mic),
        const SizedBox(height: 14),
        Text(
          LocaleKeys.mic_test_ready_hint.tr(),
          style: MoaiText.body(
            context,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
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
        _buildOrb(
          scheme,
          color: scheme.error,
          icon: MoaiIcons.mic,
          pulsing: true,
        ),
        const SizedBox(height: 14),
        _buildWaveVisualizer(scheme, color: scheme.error),
        const SizedBox(height: 12),
        _buildProgress(scheme),
        const SizedBox(height: 10),
        Text(
          LocaleKeys.mic_test_recording_active.tr(),
          style: MoaiText.body(
            context,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: scheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        _buildActionButton(
          focusNode: _recordFocus,
          icon: MoaiIcons.stopCircle,
          label: LocaleKeys.mic_test_btn_stop.tr(
            namedArgs: {'seconds': '$_recordSeconds'},
          ),
          destructive: true,
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
          _buildOrb(
            scheme,
            color: scheme.primary,
            icon: _isPlaying ? MoaiIcons.volume : MoaiIcons.checkCircle,
            pulsing: _isPlaying,
          ),
          const SizedBox(height: 14),
          if (_isPlaying) ...[
            _buildWaveVisualizer(scheme, color: scheme.primary),
            const SizedBox(height: 10),
            Text(
              LocaleKeys.mic_test_playing_active.tr(),
              style: MoaiText.body(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(
                  scheme,
                  icon: MoaiIcons.checkCircle,
                  label: LocaleKeys.mic_test_badge_ready.tr(),
                  highlighted: true,
                ),
                _chip(
                  scheme,
                  icon: MoaiIcons.volume,
                  label: LocaleKeys.mic_test_badge_amplified.tr(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              LocaleKeys.mic_test_success_desc.tr(namedArgs: {'kb': kbStr}),
              style: MoaiText.body(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ] else ...[
          _buildOrb(scheme, color: scheme.error, icon: MoaiIcons.warning),
          const SizedBox(height: 14),
          Text(
            LocaleKeys.mic_test_empty_desc.tr(
              namedArgs: {'bytes': '$_recordedBytes'},
            ),
            style: MoaiText.body(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 18),
        Row(
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

  /// Orbe central: círculo de cristal teñido con el ícono; con [pulsing],
  /// dos anillos que se expanden y desvanecen al ritmo de la onda.
  Widget _buildOrb(
    ColorScheme scheme, {
    required Color color,
    required IconData icon,
    bool pulsing = false,
  }) {
    const size = 72.0;
    const canvas = 112.0;

    final core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0.14)],
        ),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Icon(icon, size: MoaiIconSizes.xl, color: color),
    );

    return SizedBox(
      width: canvas,
      height: canvas,
      child: pulsing
          ? AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                final t = _waveController.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final phase in const [0.0, 0.5])
                      _ring(color, (t + phase) % 1.0, size, canvas),
                    child!,
                  ],
                );
              },
              child: core,
            )
          : Center(child: core),
    );
  }

  Widget _ring(Color color, double t, double size, double canvas) {
    final diameter = size + (canvas - size) * t;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.45 * (1 - t)),
          width: 1.5,
        ),
      ),
    );
  }

  /// Progreso de la grabación: contador y una línea fina que se llena en 6 s.
  Widget _buildProgress(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          '0:0$_recordSeconds',
          style: MoaiText.body(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: scheme.error,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: _recordSeconds / _maxSeconds),
              duration: const Duration(milliseconds: 900),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                color: scheme.error,
                backgroundColor: (dark ? Colors.white : scheme.onSurface)
                    .withValues(alpha: 0.08),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '0:0$_maxSeconds',
          style: MoaiText.body(
            context,
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Onda simétrica: barras finas con envolvente (más altas al centro) que
  /// ondulan con [_waveController].
  Widget _buildWaveVisualizer(ColorScheme scheme, {required Color color}) {
    const bars = 23;
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        final t = _waveController.value * 2 * math.pi;
        return SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(bars, (i) {
              final x = (i - (bars - 1) / 2) / ((bars - 1) / 2); // -1..1
              final envelope = math.exp(-2.2 * x * x);
              final wave = 0.55 + 0.45 * math.sin(t + i * 0.9);
              final height = (6 + 30 * envelope * wave).clamp(4.0, 36.0);
              return Container(
                width: 4,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.45 + 0.5 * envelope),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _chip(
    ColorScheme scheme, {
    required IconData icon,
    required String label,
    bool highlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: moaiGlassChipDecoration(scheme, highlighted: highlighted),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: MoaiIconSizes.sm, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: MoaiText.body(
              context,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// Pie discreto: consejo de uso y entrada de audio detectada.
  Widget _buildInfoFooter(ColorScheme scheme) {
    final devNames = _devices
        .map((d) => d['name']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    final infoText = devNames.isNotEmpty
        ? devNames.join(', ')
        : LocaleKeys.mic_test_no_devices.tr();

    Widget line(IconData icon, String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: MoaiIconSizes.sm, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(
              context,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          line(MoaiIcons.tip, LocaleKeys.mic_test_tip.tr()),
          const SizedBox(height: 6),
          line(
            MoaiIcons.tv,
            LocaleKeys.mic_test_devices_header.tr(
              namedArgs: {'info': infoText},
            ),
          ),
        ],
      ),
    );
  }

  /// Aviso de error: chip de cristal con tinte rojo.
  Widget _buildError(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(MoaiIcons.warning, size: MoaiIconSizes.sm, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: MoaiText.body(
                context,
                fontSize: 12,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Botón del escenario: cristal en reposo (tinte de acento si es el
  /// principal); con foco, acento (o rojo si es [destructive]) con brillo y
  /// halo.
  Widget _buildActionButton({
    required FocusNode focusNode,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
    bool destructive = false,
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
          final accent = destructive ? scheme.error : scheme.primary;

          final Decoration decoration;
          final Color fg;
          if (isFocused) {
            decoration = BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.transparent),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(accent, Colors.white, 0.18)!, accent],
              ),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 16),
              ],
            );
            fg = destructive ? scheme.onError : scheme.onPrimary;
          } else {
            decoration = moaiGlassChipDecoration(
              scheme,
              radius: 14,
              highlighted: isPrimary,
            );
            fg = destructive
                ? scheme.error
                : (isPrimary ? scheme.primary : scheme.onSurface);
          }

          return GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: decoration,
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
                        fontWeight: FontWeight.w700,
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
