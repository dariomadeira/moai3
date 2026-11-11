part of '../loading_screen.dart';

/// Las piezas de la pantalla: logo, estado y error.
extension _LoadingViews on _LoadingScreenState {
  /// Mascota e isotipo de Moai.
  Widget _buildLogo(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/moaiAbout.png',
          height: 112,
          cacheHeight: (112 * MediaQuery.devicePixelRatioOf(context)).ceil(),
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 14),
        SvgPicture.asset(
          'assets/svgs/appLogo.svg',
          height: 24,
          // Del mismo gris oscuro que el logo del Inicio.
          colorFilter: ColorFilter.mode(
            MoaiPalette.of(context).inkMuted,
            BlendMode.srcIn,
          ),
        ),
      ],
    );
  }

  /// Recuadro de vidrio con la
  /// etapa, qué está haciendo y la barra de progreso en el acento.
  Widget _buildStatusCard(BuildContext context, ColorScheme scheme) {
    final showCancel = _catalogUpdateInProgress && !_catalogCancelRequested;
    return SizedBox(
      key: const ValueKey('loading_status'),
      width: 400,
      child: MoaiGlass(
        borderRadius: MoaiGlass.panelRadius,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _icon,
                    key: ValueKey(_icon),
                    size: MoaiIconSizes.lg,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _statusText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MoaiText.body(
                          context,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (_detailText != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _detailText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MoaiText.body(
                            context,
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                minHeight: 4,
                color: scheme.primary,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.10),
              ),
            ),
            if (showCancel) ...[
              const SizedBox(height: 18),
              Center(
                child: TvDialogButton(
                  focusNode: _cancelCatalogFocus,
                  label: _cancelCatalogLabel(),
                  icon: MoaiIcons.check,
                  autofocus: true,
                  onPressed: _cancelCatalogUpdate,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// El mismo vidrio, con el aviso de error y el botón de reintento.
  Widget _buildErrorCard(BuildContext context, ColorScheme scheme) {
    return SizedBox(
      key: const ValueKey('loading_error'),
      width: 420,
      child: MoaiGlass(
        borderRadius: MoaiGlass.panelRadius,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              MoaiIcons.offline,
              size: MoaiIconSizes.xxl,
              color: scheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              LocaleKeys.loading_error_title.tr(),
              style: MoaiText.display(
                context,
                fontSize: 18,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? LocaleKeys.loading_error_connection.tr(),
              textAlign: TextAlign.center,
              style: MoaiText.body(
                context,
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TvDialogButton(
              focusNode: _retryFocusNode,
              label: LocaleKeys.update_action_retry.tr(),
              variant: TvDialogButtonVariant.primary,
              icon: MoaiIcons.refresh,
              onPressed: _startVerification,
            ),
          ],
        ),
      ),
    );
  }
}
