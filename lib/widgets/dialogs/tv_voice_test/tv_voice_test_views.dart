part of '../tv_voice_test_dialog.dart';

/// Escenario central por estado (listo, grabando, grabado): orbe con anillos,
/// onda de audio, progreso y controles; más el pie con consejo y hardware.
///
/// REDISEÑO: el escenario en el cristal de las tarjetas del Inicio, el orbe
/// en el naranja del contador del rail (rojo al grabar), etiquetas de cristal
/// y [TvDialogButton].
extension _TvVoiceTestViews on _TvVoiceTestDialogState {
  static const _maxSeconds = 6;

  /// Color del orbe: el naranja del contador del rail; rojo al grabar.
  Color get _stageColor =>
      _isRecording ? MoaiStatusTag.liveColor : MoaiCountBadge.color;

  Widget _buildMainCard(ColorScheme scheme) {
    // El cristal de las tarjetas del Inicio (más blanco que el diálogo).
    return MoaiGlass(
      borderRadius: 16,
      solid: true,
      elevated: false,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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

  Widget _hint(ColorScheme scheme, String text) => Text(
    text,
    style: MoaiText.body(
      context,
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: scheme.onSurfaceVariant,
    ),
    textAlign: TextAlign.center,
  );

  Widget _buildIdleState(ColorScheme scheme) {
    return Column(
      children: [
        _buildOrb(scheme, color: _stageColor, icon: MoaiIcons.mic),
        const SizedBox(height: 12),
        _hint(scheme, LocaleKeys.mic_test_ready_hint.tr()),
        const SizedBox(height: 18),
        TvDialogButton(
          focusNode: _recordFocus,
          icon: MoaiIcons.record,
          label: LocaleKeys.mic_test_btn_record.tr(),
          variant: TvDialogButtonVariant.primary,
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
          color: _stageColor,
          icon: MoaiIcons.mic,
          pulsing: true,
        ),
        const SizedBox(height: 12),
        _buildWaveVisualizer(scheme, color: _stageColor),
        const SizedBox(height: 12),
        _buildProgress(scheme),
        const SizedBox(height: 10),
        _hint(scheme, LocaleKeys.mic_test_recording_active.tr()),
        const SizedBox(height: 18),
        TvDialogButton(
          focusNode: _recordFocus,
          icon: MoaiIcons.stopCircle,
          label: LocaleKeys.mic_test_btn_stop.tr(
            namedArgs: {'seconds': '$_recordSeconds'},
          ),
          variant: TvDialogButtonVariant.destructive,
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
            color: MoaiCountBadge.color,
            icon: _isPlaying ? MoaiIcons.volume : MoaiIcons.checkCircle,
            pulsing: _isPlaying,
          ),
          const SizedBox(height: 12),
          if (_isPlaying) ...[
            _buildWaveVisualizer(scheme, color: MoaiCountBadge.color),
            const SizedBox(height: 10),
            _hint(scheme, LocaleKeys.mic_test_playing_active.tr()),
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
                  tint: MoaiStatusTag.soonColor,
                ),
                _chip(
                  scheme,
                  icon: MoaiIcons.volume,
                  label: LocaleKeys.mic_test_badge_amplified.tr(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _hint(
              scheme,
              LocaleKeys.mic_test_success_desc.tr(namedArgs: {'kb': kbStr}),
            ),
          ],
        ] else ...[
          _buildOrb(
            scheme,
            color: MoaiStatusTag.liveColor,
            icon: MoaiIcons.warning,
          ),
          const SizedBox(height: 12),
          _hint(
            scheme,
            LocaleKeys.mic_test_empty_desc.tr(
              namedArgs: {'bytes': '$_recordedBytes'},
            ),
          ),
        ],
        const SizedBox(height: 18),
        // Wrap: si los dos no entran (textos largos), el segundo baja.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            if (isAudioValid)
              TvDialogButton(
                focusNode: _playFocus,
                icon: _isPlaying ? MoaiIcons.stop : MoaiIcons.volume,
                label: _isPlaying
                    ? LocaleKeys.mic_test_btn_stop_play.tr()
                    : LocaleKeys.mic_test_btn_play.tr(),
                variant: TvDialogButtonVariant.primary,
                onPressed: _togglePlayback,
                onKeyRight: _rerecordFocus.requestFocus,
                onKeyDown: _closeFocus.requestFocus,
              ),
            TvDialogButton(
              focusNode: _rerecordFocus,
              icon: MoaiIcons.refresh,
              label: LocaleKeys.mic_test_btn_rerecord.tr(),
              variant: isAudioValid
                  ? TvDialogButtonVariant.neutral
                  : TvDialogButtonVariant.primary,
              onPressed: _startRecording,
              onKeyLeft: () {
                if (isAudioValid) _playFocus.requestFocus();
              },
              onKeyDown: _closeFocus.requestFocus,
            ),
          ],
        ),
      ],
    );
  }

  /// Orbe central: círculo lleno de [color] con el degradado del contador
  /// del rail, el ícono en blanco y un halo suave; con [pulsing], dos anillos
  /// que se expanden y desvanecen al ritmo de la onda.
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
          colors: [Color.lerp(color, Colors.white, 0.18)!, color],
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 18),
        ],
      ),
      child: Icon(icon, size: MoaiIconSizes.xl, color: Colors.white),
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
    const color = MoaiStatusTag.liveColor;
    return Row(
      children: [
        Text(
          '0:0$_recordSeconds',
          style: MoaiText.body(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
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
                color: color,
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

  /// Etiqueta de cristal (como el año o la duración del detalle), teñida
  /// con [tint] si se da.
  Widget _chip(
    ColorScheme scheme, {
    required IconData icon,
    required String label,
    Color? tint,
  }) {
    final fg = moaiGlassTagForeground(scheme, tint: tint);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: moaiGlassTagDecoration(scheme, tint: tint),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: MoaiIconSizes.sm, color: fg),
          const SizedBox(width: 6),
          Transform.translate(
            offset: Offset(0, MoaiText.opticalCenterShift(MoaiText.sizeCaption)),
            child: Text(
              label,
              style: MoaiText.body(
                context,
                fontSize: MoaiText.sizeCaption,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
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
    // Como las filas de Ajustes: el ícono en el acento y el texto en negro.
    final iconColor = Theme.of(context).colorScheme.primary;

    Widget line(IconData icon, String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: MoaiIconSizes.sm, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: MoaiText.body(
              context,
              fontSize: MoaiText.sizeCaption,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
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

  /// Aviso de error: etiqueta de cristal teñida de rojo.
  Widget _buildError(ColorScheme scheme) {
    const color = MoaiStatusTag.liveColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: moaiGlassTagDecoration(scheme, radius: 14, tint: color),
      child: Row(
        children: [
          const Icon(MoaiIcons.warning, size: MoaiIconSizes.sm, color: color),
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
}
