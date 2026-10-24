part of '../tv_gamepad_config_dialog.dart';

/// Columnas del diálogo: mandos detectados y tablero de botones en vivo.
extension _GamepadConfigColumns on _TvGamepadConfigDialogState {
  /// Columna 1: lista de mandos detectados.
  Widget _buildDevicesColumn(
    BuildContext context,
    ColorScheme scheme,
    BoxDecoration panelDecoration,
    Color borderColor,
    bool isConnected,
    List<GamepadDeviceInfo> connectedList,
  ) {
    return Expanded(
      flex: 10,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(MoaiIcons.gamepad, size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  LocaleKeys.gamepad_detected_section_header.tr(),
                  style: MoaiText.body(
                    context,
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (!isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
              decoration: panelDecoration,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      MoaiIcons.gamepad,
                      size: 28,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    LocaleKeys.gamepad_device_none.tr(),
                    textAlign: TextAlign.center,
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurface,
                      fontSize: 12.5,
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
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < connectedList.length; i++)
                  _GamepadDeviceCard(
                    index: i + 1,
                    device: connectedList[i],
                    decoration: panelDecoration,
                  ),
              ],
            ),
          const SizedBox(height: 10),
          // Tarjeta informativa compacta sobre controles arcade
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(MoaiIcons.infoCircle, size: 14, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    LocaleKeys.gamepad_support_two_players.tr(),
                    style: MoaiText.body(
                      context,
                      color: scheme.onSurfaceVariant,
                      fontSize: 10.5,
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

  /// Columna 2: tablero visual de botones en tiempo real (squircles M3).
  Widget _buildButtonBoard(
    BuildContext context,
    ColorScheme scheme,
    BoxDecoration panelDecoration,
    Color borderColor,
  ) {
    return Expanded(
      flex: 13,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(MoaiIcons.gamepad, size: 14, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      LocaleKeys.gamepad_test_section.tr().toUpperCase(),
                      style: MoaiText.body(
                        context,
                        color: scheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (_lastPressedLabel != null)
                  Flexible(
                    child: Text(
                      _lastPressedLabel!,
                      overflow: TextOverflow.ellipsis,
                      style: MoaiText.body(
                        context,
                        color: scheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: panelDecoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fila superior: D-Pad a la izquierda + Sistema (Coin / Start) a la derecha
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // D-Pad en cruz compacto con squircles
                    SizedBox(
                      width: 108,
                      height: 108,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Arriba
                          Positioned(
                            top: 0,
                            child: _SquircleButton(
                              icon: MoaiIcons.arrowUp,
                              isPressed:
                                  (_activeTestMask & ArcadeButtons.up) != 0,
                              size: 34,
                            ),
                          ),
                          // Izquierda
                          Positioned(
                            left: 0,
                            child: _SquircleButton(
                              icon: MoaiIcons.arrowBack,
                              isPressed:
                                  (_activeTestMask & ArcadeButtons.left) != 0,
                              size: 34,
                            ),
                          ),
                          // Centro de decoración
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(
                                alpha: 0.5,
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          // Derecha
                          Positioned(
                            right: 0,
                            child: _SquircleButton(
                              icon: MoaiIcons.arrowForward,
                              isPressed:
                                  (_activeTestMask & ArcadeButtons.right) != 0,
                              size: 34,
                            ),
                          ),
                          // Abajo
                          Positioned(
                            bottom: 0,
                            child: _SquircleButton(
                              icon: MoaiIcons.arrowDown,
                              isPressed:
                                  (_activeTestMask & ArcadeButtons.down) != 0,
                              size: 34,
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
                              isPressed:
                                  (_activeTestMask & ArcadeButtons.coin) != 0,
                              height: 34,
                              activeColor: const Color(0xFFFFB300),
                            ),
                            const SizedBox(width: 8),
                            _SquircleButton(
                              label: 'START',
                              subtitle: '1',
                              isPressed:
                                  (_activeTestMask & ArcadeButtons.start) != 0,
                              height: 34,
                              activeColor: const Color(0xFF43A047),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          LocaleKeys.gamepad_coin_start_header.tr(),
                          style: MoaiText.body(
                            context,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: borderColor.withValues(alpha: 0.4),
                  ),
                ),
                // Botonera de Acción Arcade (CPS / Lucha: 6 botones)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      LocaleKeys.gamepad_attacks_cps_header.tr(),
                      style: MoaiText.body(
                        context,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      LocaleKeys.gamepad_levels_weak_med_strong.tr(),
                      style: MoaiText.body(
                        context,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Fila 1: Golpes (LP, MP, HP)
                Row(
                  children: [
                    Expanded(
                      child: _SquircleButton(
                        label: 'LP',
                        subtitle: 'X',
                        isPressed:
                            (_activeTestMask & ArcadeButtons.punchLight) != 0,
                        height: 38,
                        activeColor: const Color(0xFFE53935),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _SquircleButton(
                        label: 'MP',
                        subtitle: 'Y',
                        isPressed:
                            (_activeTestMask & ArcadeButtons.punchMedium) != 0,
                        height: 38,
                        activeColor: const Color(0xFFFB8C00),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _SquircleButton(
                        label: 'HP',
                        subtitle: 'R1',
                        isPressed:
                            (_activeTestMask & ArcadeButtons.punchHeavy) != 0,
                        height: 38,
                        activeColor: const Color(0xFF1E88E5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Fila 2: Patadas (LK, MK, HK)
                Row(
                  children: [
                    Expanded(
                      child: _SquircleButton(
                        label: 'LK',
                        subtitle: 'A',
                        isPressed:
                            (_activeTestMask & ArcadeButtons.kickLight) != 0,
                        height: 38,
                        activeColor: const Color(0xFFD81B60),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _SquircleButton(
                        label: 'MK',
                        subtitle: 'B',
                        isPressed:
                            (_activeTestMask & ArcadeButtons.kickMedium) != 0,
                        height: 38,
                        activeColor: const Color(0xFF8E24AA),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _SquircleButton(
                        label: 'HK',
                        subtitle: 'R2',
                        isPressed:
                            (_activeTestMask & ArcadeButtons.kickHeavy) != 0,
                        height: 38,
                        activeColor: const Color(0xFF3949AB),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
