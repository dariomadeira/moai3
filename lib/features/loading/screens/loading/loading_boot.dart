part of '../loading_screen.dart';

/// El arranque: verificación, sesión, catálogo y secciones que faltan.
extension _LoadingBoot on _LoadingScreenState {
  Future<void> _startVerification() async {
    _update(() {
      _isLoading = true;
      _errorMessage = null;
      _step = _BootStep.device;
      _statusText = LocaleKeys.loading_connecting.tr();
      _icon = _BootStep.device.icon;
      _detailText = null;
    });

    MoiamovApiService.logLine('▶ Inicio de verificación de arranque Moai');

    final startTime = DateTime.now();

    try {
      final identity = await widget.identityService.getIdentity();
      final localNickname = widget.identityService.getNickname();
      final result = await widget.presenceService.verifyAndRegisterDevice(
        deviceId: identity.deviceId,
        appVersion: identity.appVersion,
        nickname: localNickname,
      );

      if (!mounted) return;

      final record = result.record;
      if (record.userCode != null) {
        await widget.identityService.saveUserCode(record.userCode!);
      }
      if (record.nickname != null && record.nickname!.trim().isNotEmpty) {
        await widget.identityService.saveNickname(record.nickname!.trim());
      } else if (localNickname != null && localNickname.trim().isNotEmpty) {
        await widget.identityService.saveNickname(localNickname.trim());
      }

      if (!mounted) return;

      final userCode = record.userCode;
      if (userCode != null) {
        context.read<WatchPartyProvider?>()?.updateUserCode(userCode);
      }

      // Si el dispositivo está bloqueado (RB-04 / CASO-UC-02)
      if (!record.isActive) {
        context.go('/blocked', extra: record.blockReason);
        return;
      }

      if (kStartupLoginEnabled) {
        await _syncSessionAndCatalog(context.read<TvSettingsProvider>());
        if (!mounted) return;

        // Un mínimo para que el arranque no sea un parpadeo.
        final elapsed = DateTime.now().difference(startTime);
        if (elapsed < const Duration(milliseconds: 1200)) {
          await Future.delayed(const Duration(milliseconds: 1200) - elapsed);
        }

        if (!mounted) return;

        _setStep(_BootStep.ready, LocaleKeys.loading_ready);
        await Future.delayed(const Duration(milliseconds: 700));
      } else {
        // Desarrollo: sin login, con el catálogo guardado.
        MoiamovApiService.logLine(
          '⏭ Login de arranque desactivado (desarrollo)',
        );
        final available = await MoiamovApiService.instance.savedSections();
        if (!mounted) return;
        context.read<FeaturedMoviesProvider>().setAvailableSections(available);
      }

      if (!mounted) return;

      // Dispositivo activo -> Ir a Overlap, NicknameSetup o Home
      final effectiveNick =
          (record.nickname != null && record.nickname!.trim().isNotEmpty)
          ? record.nickname!.trim()
          : (localNickname != null && localNickname.trim().isNotEmpty
                ? localNickname.trim()
                : widget.identityService.getNickname()?.trim());

      if (!context.read<TvSettingsProvider>().hasOverlapConfig) {
        context.go('/overlap');
      } else if (effectiveNick == null || effectiveNick.isEmpty) {
        context.go('/nickname_setup');
      } else {
        context.go('/home');
      }
    } catch (e, st) {
      MoiamovApiService.logLine(
        e is TimeoutException
            ? '❌ Verificación del dispositivo: $e'
            : '❌ Verificación del dispositivo: $e\n$st',
      );
      try {
        await VpnService.instance.disconnect();
      } catch (e) {
        MoiamovApiService.logLine('⚠️ No se pudo desconectar la VPN: $e');
      }
      if (!mounted) return;
      _update(() {
        _isLoading = false;
        _errorMessage = LocaleKeys.loading_error_connection.tr();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _retryFocusNode.requestFocus();
      });
    }
  }

  /// Sesión y, si toca, descarga del catálogo (SPEC-39 §4). Con la sesión
  /// del último login todavía vigente no se usa la VPN; si no, túnel +
  /// login ([_connectAndLogin]). No lanza: sin sesión, Destacados,
  /// Películas y Series quedan ocultas y se sigue al home.
  Future<void> _syncSessionAndCatalog(TvSettingsProvider tvSettings) async {
    final api = MoiamovApiService.instance;
    final vpn = VpnService.instance;
    var sessionOk = false;

    try {
      final hasCatalog = (await api.savedSections()).isNotEmpty;
      _storedCatalogAt = await api.lastSavedCatalogAt();
      final needsUpdate =
          !hasCatalog ||
          TvSettingsProvider.shouldAttemptCatalogUpdate(
            savedAt: _storedCatalogAt,
            frequency: tvSettings.catalogUpdateFrequency,
          );
      MoiamovApiService.logLine(
        'Arranque: catálogo=${hasCatalog ? 'sí' : 'no'} '
        'fecha=${_storedCatalogAt?.toIso8601String() ?? 'null'} '
        'freq=${tvSettings.catalogUpdateFrequency.storageValue} '
        '→ actualizar=$needsUpdate',
      );

      api.beginCatalogSync();
      vpn.resetConnectCancellation();
      _catalogCancelRequested = false;
      final downloaded = <String>{};
      bool catalogDone() =>
          !needsUpdate ||
          _catalogCancelRequested ||
          downloaded.length == _LoadingScreenState._catalogSections.length;

      // Primero, sin VPN: si la sesión del último login sigue vigente no
      // hace falta el túnel (sólo el login exige la región) y el catálogo
      // baja igual. La VPN queda para el primer arranque y para cuando la
      // sesión venció.
      _setStep(_BootStep.session, LocaleKeys.loading_session_init);
      final saved = await api.checkSavedSession();
      if (saved == SavedSessionStatus.valid && mounted) {
        sessionOk = true;
        if (needsUpdate) {
          await _downloadMissingSections(downloaded, showCancel: hasCatalog);
        }
        if (!catalogDone()) {
          MoiamovApiService.logLine(
            'Faltan secciones (${downloaded.length}/${_LoadingScreenState._catalogSections.length}) '
            'con la sesión guardada; se prueba con VPN...',
          );
        }
      }

      var usedVpn = false;
      if (!sessionOk || !catalogDone()) {
        usedVpn = true;
        await _connectAndLogin(
          downloaded: downloaded,
          needsUpdate: needsUpdate,
          hasCatalog: hasCatalog,
          onSession: () => sessionOk = true,
        );
      }

      if (usedVpn) {
        _setStep(_BootStep.ready, LocaleKeys.loading_secure_disconnecting);
        await vpn.disconnect();
        await _pause(const Duration(milliseconds: 300));
      }

      // La fecha cambia solo con las 3 secciones: si falta alguna, el
      // próximo arranque vuelve a intentar.
      final complete =
          downloaded.length == _LoadingScreenState._catalogSections.length;
      if (complete) await api.saveCatalogDate(DateTime.now());

      final String status;
      if (!sessionOk) {
        status = LocaleKeys.loading_session_failed;
      } else if (complete) {
        status = LocaleKeys.loading_catalog_updated;
      } else if (needsUpdate && !_catalogCancelRequested) {
        status = LocaleKeys.loading_catalog_not_updated;
      } else {
        status = LocaleKeys.loading_catalog_cached;
      }
      _setStep(_BootStep.ready, status);
      await _pause(const Duration(milliseconds: 1200));
    } catch (e) {
      MoiamovApiService.logLine('⚠️ Error en VPN, login o catálogo: $e');
      try {
        await vpn.disconnect();
      } catch (e) {
        MoiamovApiService.logLine('⚠️ No se pudo desconectar la VPN: $e');
      }
    }

    final available = sessionOk ? await api.savedSections() : const <String>{};
    MoiamovApiService.logLine('Secciones disponibles: $available');
    if (mounted) {
      context.read<FeaturedMoviesProvider>().setAvailableSections(available);
    }
  }

  /// Túnel + login, recorriendo todos los endpoints en el orden del ranking
  /// (SPEC-39 §4.1) hasta conseguir la sesión y, si toca, el catálogo. No
  /// hay tope de intentos: pasan todos los servidores, y cada falla
  /// reacomoda la cola según su causa ([VpnAttemptQueue]). Sí hay un tope de
  /// tiempo ([_LoadingScreenState._vpnBudget]): con la red muda cada intento
  /// tarda 14 s. Los resultados se anotan en el ranking al final.
  Future<void> _connectAndLogin({
    required Set<String> downloaded,
    required bool needsUpdate,
    required bool hasCatalog,
    required VoidCallback onSession,
  }) async {
    final api = MoiamovApiService.instance;
    final vpn = VpnService.instance;
    final ranking = VpnNodeRanking();
    final queue = VpnAttemptQueue(await ranking.orderedEndpoints());
    final results = <VpnAttemptResult>[];
    final started = DateTime.now();
    // Si algún servidor contestó (túnel arriba o autenticación rechazada)
    // hay internet y las fallas son de los endpoints: se anotan.
    var anyAnswer = false;

    Future<void> rotate(VpnEndpoint failed, VpnFailure failure) async {
      queue.failed(failed, failure);
      _setStep(_BootStep.secure, LocaleKeys.loading_secure_retry);
      await vpn.disconnect();
      await _pause(const Duration(milliseconds: 500));
    }

    // El permiso VPN se pide dentro de connect (el plugin guarda la
    // config, muestra el aviso del SO y al OK arranca el túnel). No usar
    // requestPermissionAndroid aparte: devuelve false al mostrar el diálogo.
    for (var attempt = 1; queue.isNotEmpty && mounted; attempt++) {
      if (DateTime.now().difference(started) > _LoadingScreenState._vpnBudget) {
        MoiamovApiService.logLine(
          'Se agotó el tiempo de la VPN: quedan ${queue.pending.length} '
          'endpoints sin probar.',
        );
        break;
      }
      final endpoint = queue.next();
      final total = attempt + queue.pending.length;
      final attemptStart = DateTime.now();
      final detail = attempt > 1 ? _attemptDetail(attempt, total) : null;
      _setStep(
        _BootStep.secure,
        LocaleKeys.loading_secure_connecting,
        detail: detail,
      );
      MoiamovApiService.logLine('Intento $attempt/$total: $endpoint');

      final connection = await vpn.connect(
        endpoint,
        onStatusUpdate: _setStatus,
      );
      if (connection == VpnConnectResult.permissionDenied) {
        MoiamovApiService.logLine('Permiso VPN rechazado por el usuario.');
        break;
      }
      if (connection == VpnConnectResult.cancelled) break;
      if (connection != VpnConnectResult.connected) {
        final auth = connection == VpnConnectResult.authFailed;
        if (auth) anyAnswer = true;
        results.add((
          endpoint: endpoint,
          attempt: VpnAttempt.failure,
          elapsed: null,
        ));
        MoiamovApiService.logLine(
          auth
              ? '$endpoint: el servidor rechazó la autenticación.'
              : '$endpoint: el túnel no conectó.',
        );
        await rotate(endpoint, auth ? VpnFailure.auth : VpnFailure.noAnswer);
        continue;
      }
      anyAnswer = true;

      // Por dónde sale, sólo para el log: no frena el arranque (si la
      // región no sirve, lo dice el portal al pedir la sesión).
      final country = endpoint.node.country;
      unawaited(
        vpn
            .checkExit(country: country)
            .then(
              (exit) => MoiamovApiService.logLine(
                'Salida $endpoint: ${vpn.lastExitIp} '
                '(${vpn.lastExitCountry}, esperado $country: ${exit.name})',
              ),
            ),
      );

      // Un respiro para que la interfaz tun0 tenga rutas y DNS.
      _setStep(
        _BootStep.secure,
        LocaleKeys.loading_secure_verified,
        detail: detail,
      );
      await _pause(const Duration(milliseconds: 1000));
      _setStep(
        _BootStep.session,
        LocaleKeys.loading_session_init,
        detail: detail,
      );
      MoiamovApiService.logLine(
        'Solicitando sesión de dispositivo (sin credenciales)...',
      );
      var session = await api.ensureSession();
      // Un corte de red apenas sube el túnel suele pasar solo: se
      // reintenta una vez con el mismo endpoint antes de cambiarlo.
      if (!session && api.lastSessionNetworkFailure && mounted) {
        MoiamovApiService.logLine(
          '$endpoint: la red no contestó; reintento con el mismo...',
        );
        await _pause(const Duration(milliseconds: 1500));
        if (!_catalogCancelRequested) session = await api.ensureSession();
      }
      if (!session) {
        final region = api.lastSessionRegionRejected;
        results.add((
          endpoint: endpoint,
          // Sin respuesta de la red no es culpa del endpoint.
          attempt: api.lastSessionNetworkFailure
              ? VpnAttempt.transient
              : VpnAttempt.failure,
          elapsed: null,
        ));
        MoiamovApiService.logLine(
          region
              ? '$endpoint: el portal rechazó la salida; otro servidor...'
              : api.lastSessionNetworkFailure
              ? '$endpoint: la red sigue sin contestar; rotando...'
              : '$endpoint: sesión rechazada; rotando...',
        );
        // Con la región rechazada, los otros puertos del mismo servidor
        // salen por la misma IP: se descartan.
        await rotate(endpoint, region ? VpnFailure.region : VpnFailure.session);
        continue;
      }
      onSession();
      final sessionTime = DateTime.now().difference(attemptStart);
      MoiamovApiService.logLine(
        '✅ Sesión de dispositivo obtenida (${sessionTime.inMilliseconds}ms).',
      );
      // El endpoint sirvió aunque después falle el catálogo: eso depende
      // del servidor del portal, no de la VPN.
      results.add((
        endpoint: endpoint,
        attempt: VpnAttempt.success,
        elapsed: sessionTime,
      ));

      if (!needsUpdate) break;
      await _downloadMissingSections(downloaded, showCancel: hasCatalog);
      if (_catalogCancelRequested) break;
      if (downloaded.length == _LoadingScreenState._catalogSections.length) {
        break;
      }
      MoiamovApiService.logLine(
        'Faltan secciones (${downloaded.length}/${_LoadingScreenState._catalogSections.length}); '
        'rotando...',
      );
      await rotate(endpoint, VpnFailure.session);
    }

    // Si nadie contestó, lo más probable es que no haya internet: no es
    // culpa de los endpoints y no se anota.
    if (anyAnswer) {
      await ranking.recordAll(results);
    } else if (results.isNotEmpty) {
      MoiamovApiService.logLine(
        'Ningún servidor contestó: el ranking no se modifica.',
      );
    }
  }

  /// Baja las secciones que faltan: Películas primero, Destacados y Series juntas.
  Future<void> _downloadMissingSections(
    Set<String> downloaded, {
    required bool showCancel,
  }) async {
    if (!mounted) return;
    String progress() => LocaleKeys.loading_catalog_progress.tr(
      namedArgs: {
        'done': '${downloaded.length}',
        'total': '${_LoadingScreenState._catalogSections.length}',
      },
    );
    _setStep(
      _BootStep.catalog,
      LocaleKeys.loading_catalog_downloading,
      detail: progress(),
    );
    _update(() => _catalogUpdateInProgress = showCancel);
    if (showCancel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _catalogUpdateInProgress) {
          _cancelCatalogFocus.requestFocus();
        }
      });
    }

    Future<void> download(String section) async {
      if (_catalogCancelRequested || downloaded.contains(section)) return;
      final result = await MoiamovApiService.instance.syncCatalog(
        section: section,
        timeout: const Duration(seconds: 12),
      );
      if (result.isFreshLive) {
        downloaded.add(section);
        _setDetail(progress());
      }
    }

    await download(FeaturedMoviesProvider.sectionMovies);
    await Future.wait([
      download(FeaturedMoviesProvider.sectionFeatured),
      download(FeaturedMoviesProvider.sectionSeries),
    ]);

    if (mounted) _update(() => _catalogUpdateInProgress = false);
  }
}
