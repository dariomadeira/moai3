part of '../tv_gamepad_config_dialog.dart';

/// Columnas del diálogo: mandos detectados y tablero de botones en vivo.
///
/// REDISEÑO (2026-11-04): cada columna es una ficha de cristal (como el
/// escenario de la prueba de voz), con el encabezado de ícono en el acento y texto
/// negro; sin mando, un orbe gris pizarra.
extension _GamepadConfigColumns on _TvGamepadConfigDialogState {
  /// Encabezado de sección: texto negro, sin ícono. [trailing] va a la
  /// derecha (p. ej. el último botón).
  Widget _sectionHeader(
    BuildContext context,
    ColorScheme scheme,
    String text, {
    Widget? trailing,
  }) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MoaiText.body(
                context,
                color: scheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  /// La ficha de cristal de cada columna.
  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return MoaiGlass(
      borderRadius: MoaiGlass.panelRadius,
      solid: true,
      elevated: false,
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }

  /// Columna 1: lista de mandos detectados.
  Widget _buildDevicesColumn(
    BuildContext context,
    ColorScheme scheme,
    bool isConnected,
    List<GamepadDeviceInfo> connectedList,
  ) {
    return Expanded(
      flex: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
            context,
            scheme,
            LocaleKeys.gamepad_detected_section_header.tr(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _card(
              child: isConnected
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < connectedList.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _GamepadDeviceCard(
                            index: i + 1,
                            device: connectedList[i],
                          ),
                        ],
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _orb(MoaiStatusTag.finishedColor, MoaiIcons.gamepad),
                        const SizedBox(height: 14),
                        Text(
                          LocaleKeys.gamepad_device_none.tr(),
                          textAlign: TextAlign.center,
                          style: MoaiText.body(
                            context,
                            color: scheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          LocaleKeys.gamepad_device_none_hint.tr(),
                          textAlign: TextAlign.center,
                          style: MoaiText.body(
                            context,
                            color: scheme.onSurfaceVariant,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Pie discreto, como el consejo de la prueba de voz.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  MoaiIcons.infoCircle,
                  size: MoaiIconSizes.sm,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    LocaleKeys.gamepad_support_two_players.tr(),
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Orbe del estado vacío: círculo lleno de [color] con degradado, ícono
  /// blanco y halo suave (el de la prueba de voz).
  Widget _orb(Color color, IconData icon) {
    return Container(
      width: 64,
      height: 64,
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
  }

  bool _on(int bit) => (_activeTestMask & bit) != 0;

  /// Columna 2: tablero visual de botones en tiempo real.
  Widget _buildButtonBoard(
    BuildContext context,
    ColorScheme scheme,
    Color borderColor,
  ) {
    final last = _lastPressedLabel;
    return Expanded(
      flex: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
            context,
            scheme,
            LocaleKeys.gamepad_test_section.tr(),
            // El último botón, en la pastilla del acento de los géneros.
            trailing: last == null
                ? null
                : TvMetaPill(
                    label: last,
                    tint: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          _card(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fila superior: D-Pad a la izquierda + Sistema (Coin / Start) a la derecha
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // D-Pad en cruz
                    SizedBox(
                      width: 124,
                      height: 124,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 0,
                            child: _SquircleButton(
                              icon: MoaiIcons.arrowUp,
                              isPressed: _on(ArcadeButtons.up),
                              size: 40,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            child: _SquircleButton(
                              icon: MoaiIcons.arrowBack,
                              isPressed: _on(ArcadeButtons.left),
                              size: 40,
                            ),
                          ),
                          // Centro de la cruz
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: scheme.onSurface.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            child: _SquircleButton(
                              icon: MoaiIcons.arrowForward,
                              isPressed: _on(ArcadeButtons.right),
                              size: 40,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            child: _SquircleButton(
                              icon: MoaiIcons.arrowDown,
                              isPressed: _on(ArcadeButtons.down),
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Botones de Sistema: COIN y START
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SquircleButton(
                              label: 'COIN',
                              subtitle: '5/9',
                              isPressed: _on(ArcadeButtons.coin),
                              height: 40,
                              activeColor: const Color(0xFFFFB300),
                            ),
                            const SizedBox(width: 8),
                            _SquircleButton(
                              label: 'START',
                              subtitle: '1',
                              isPressed: _on(ArcadeButtons.start),
                              height: 40,
                              activeColor: const Color(0xFF43A047),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          LocaleKeys.gamepad_coin_start_header.tr(),
                          style: MoaiText.body(
                            context,
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, thickness: 1, color: borderColor),
                ),
                // Botonera de Acción Arcade (CPS / Lucha: 6 botones)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      LocaleKeys.gamepad_attacks_cps_header.tr(),
                      style: MoaiText.body(
                        context,
                        color: scheme.onSurface,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      LocaleKeys.gamepad_levels_weak_med_strong.tr(),
                      style: MoaiText.body(
                        context,
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Fila 1: Golpes (LP, MP, HP)
                _attackRow([
                  (
                    'LP',
                    'X',
                    ArcadeButtons.punchLight,
                    const Color(0xFFE53935),
                  ),
                  (
                    'MP',
                    'Y',
                    ArcadeButtons.punchMedium,
                    const Color(0xFFFB8C00),
                  ),
                  (
                    'HP',
                    'R1',
                    ArcadeButtons.punchHeavy,
                    const Color(0xFF1E88E5),
                  ),
                ]),
                const SizedBox(height: 8),
                // Fila 2: Patadas (LK, MK, HK)
                _attackRow([
                  ('LK', 'A', ArcadeButtons.kickLight, const Color(0xFFD81B60)),
                  (
                    'MK',
                    'B',
                    ArcadeButtons.kickMedium,
                    const Color(0xFF8E24AA),
                  ),
                  (
                    'HK',
                    'R2',
                    ArcadeButtons.kickHeavy,
                    const Color(0xFF3949AB),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Una fila de tres botones de ataque: (etiqueta, tecla, bit, color).
  Widget _attackRow(List<(String, String, int, Color)> buttons) {
    return Row(
      children: [
        for (final (i, (label, key, bit, color)) in buttons.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _SquircleButton(
              label: label,
              subtitle: key,
              isPressed: _on(bit),
              height: 44,
              activeColor: color,
            ),
          ),
        ],
      ],
    );
  }
}
