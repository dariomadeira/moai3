import 'package:moai3/l10n/locale_keys.g.dart';
import 'package:moai3/platform/platform_channels.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:http/http.dart' as http;
import 'package:openvpn_flutter/openvpn_flutter.dart';
import '../config/constants.dart';
import 'vpn_nodes.dart';

/// Resultado de [VpnService.connect].
enum VpnConnectResult {
  /// Túnel arriba y salida por el país esperado.
  connected,

  /// El túnel no llegó a conectar.
  tunnelFailed,

  /// Conectó, pero la salida no es del país del nodo.
  wrongCountry,

  /// El usuario rechazó el permiso VPN del sistema.
  permissionDenied,

  /// Cortado desde la app.
  cancelled,
}

/// Servicio centralizado de VPN open source integrado en Moai TV
class VpnService {
  static final VpnService instance = VpnService._internal();

  VpnService._internal();

  OpenVPN? _engine;
  bool _isInitialized = false;
  VPNStage _currentStage = VPNStage.disconnected;
  VpnStatus? _currentStatus;

  /// Última IP pública y país detectados al validar el túnel (para mostrarlo en pantalla).
  String _lastExitIp = '';
  String _lastExitCountry = '';
  String get lastExitIp => _lastExitIp;
  String get lastExitCountry => _lastExitCountry;

  final StreamController<VPNStage> _stageController =
      StreamController<VPNStage>.broadcast();

  Stream<VPNStage> get stageStream => _stageController.stream;
  VPNStage get currentStage => _currentStage;
  VpnStatus? get currentStatus => _currentStatus;
  bool get isConnected => _currentStage == VPNStage.connected;

  bool _connectCancelled = false;

  /// Resultado del diálogo de VPN de Android en esta sesión de proceso.
  /// `null` = aún no se pidió; evita reabrir el aviso al rotar nodos.
  bool? _androidVpnPermissionGranted;

  static const MethodChannel _vpnPermissionChannel =
      PlatformChannels.vpnPermission;

  bool _permissionChannelWired = false;

  void _ensurePermissionChannel() {
    if (_permissionChannelWired) return;
    _permissionChannelWired = true;
    _vpnPermissionChannel.setMethodCallHandler((call) async {
      if (call.method == 'denied') {
        debugPrint('⚠️ [VPN] Permiso denegado (nativo).');
        _androidVpnPermissionGranted = false;
        _connectCancelled = true;
        try {
          _engine?.disconnect();
        } catch (_) {}
      }
      return null;
    });
  }

  /// `true` si el usuario rechazó el permiso VPN del sistema en este arranque.
  bool get permissionDenied => _androidVpnPermissionGranted == false;

  /// Pregunta a Android si el permiso VPN ya está concedido (no muestra nada).
  Future<bool> _isPermissionGrantedNative() async {
    try {
      return await _vpnPermissionChannel.invokeMethod<bool>('isGranted') ??
          false;
    } catch (e) {
      debugPrint('⚠️ [VPN] No se pudo consultar el permiso: $e');
      return false;
    }
  }

  /// Corta el intento de conexión en curso para salir del arranque sin esperar el timeout.
  void cancelConnect() {
    _connectCancelled = true;
    try {
      _engine?.disconnect();
    } catch (_) {}
  }

  /// Limpia cancelaciones previas antes de un nuevo intento de sync.
  void resetConnectCancellation() {
    _connectCancelled = false;
  }

  /// Asegura el selector de salida Proton `+b:0` (México en estos perfiles).
  static String _ensureMexicoExitUsername(String username) {
    final base = username.split('+').first.trim();
    if (base.isEmpty) return username;
    // Conserva extras (+f1, +nr, etc.) si ya venían; fuerza +b:0 delante.
    final extras = RegExp(r'\+(?!b:\d+)([^+]+)')
        .allMatches(username)
        .map((m) => '+${m.group(1)}')
        .join();
    return '$base+b:0$extras';
  }

  /// openvpn_flutter (android_16kb) a veces exige data-ciphers explícito.
  static String _ensureDataCiphers(String cfg) {
    if (cfg.contains('data-ciphers')) return cfg;
    if (cfg.contains('cipher AES-256-GCM')) {
      return cfg.replaceFirst(
        'cipher AES-256-GCM',
        "cipher AES-256-GCM\n"
        "data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC:AES-128-CBC\n"
        "data-ciphers-fallback AES-256-GCM",
      );
    }
    if (cfg.contains('cipher AES-128-CBC')) {
      return cfg.replaceFirst(
        'cipher AES-128-CBC',
        "cipher AES-128-CBC\n"
        "data-ciphers AES-128-CBC\n"
        "data-ciphers-fallback AES-128-CBC",
      );
    }
    if (cfg.contains('cipher AES-256-CBC')) {
      return cfg.replaceFirst(
        'cipher AES-256-CBC',
        "cipher AES-256-CBC\n"
        "data-ciphers AES-256-CBC\n"
        "data-ciphers-fallback AES-256-CBC",
      );
    }
    return cfg;
  }

  Future<void> initialize() async {
    _ensurePermissionChannel();
    if (_isInitialized) return;

    _engine = OpenVPN(
      onVpnStageChanged: (stage, raw) {
        debugPrint('🔒 [VPN Stage] $stage ($raw)');
        _currentStage = stage;
        _stageController.add(stage);
      },
      onVpnStatusChanged: (status) {
        _currentStatus = status;
      },
    );

    await _engine!.initialize(
      lastStage: (stage) {
        _currentStage = stage;
        _stageController.add(stage);
      },
      lastStatus: (status) {
        _currentStatus = status;
      },
    );

    _isInitialized = true;
    debugPrint('🔒 [VPN] OpenVPN inicializado correctamente.');
  }

  /// El plugin `requestPermissionAndroid` **no espera** al usuario: si hay que
  /// mostrar el diálogo, devuelve `false` al instante. Por eso el permiso se
  /// obtiene dentro de [connect] (guarda config → diálogo → connectWhileGranted).
  ///
  /// Este método solo tipa el status de UI; siempre deja seguir a connect.
  Future<void> prepareAndroidVpnPermissionUi({
    void Function(String message)? onStatusUpdate,
  }) async {
    await initialize();
    if (_androidVpnPermissionGranted == null && await _isPermissionGrantedNative()) {
      _androidVpnPermissionGranted = true;
    }
    if (_androidVpnPermissionGranted == true) return;
    onStatusUpdate?.call(LocaleKeys.loading_permission_required);
  }

  /// Conecta [node] y verifica que salga por su país.
  Future<VpnConnectResult> connect(
    VpnNode node, {
    Duration timeout = const Duration(seconds: 14),
    void Function(String message)? onStatusUpdate,
  }) async {
    _connectCancelled = false;
    await initialize();
    if (_androidVpnPermissionGranted == false) {
      debugPrint('⚠️ [VPN] Permiso ya denegado en esta sesión.');
      return VpnConnectResult.permissionDenied;
    }
    if (_connectCancelled) return VpnConnectResult.cancelled;

    await prepareAndroidVpnPermissionUi(onStatusUpdate: onStatusUpdate);
    if (_connectCancelled) return VpnConnectResult.cancelled;

    onStatusUpdate?.call(LocaleKeys.loading_init_services);
    debugPrint('🔒 [VPN] Nodo ${node.id} (${node.asset})');

    String ovpnConfig;
    try {
      ovpnConfig = await rootBundle.loadString(node.asset);
    } catch (e) {
      debugPrint('❌ [VPN] Error al cargar ${node.asset}: $e');
      return VpnConnectResult.tunnelFailed;
    }
    if (ovpnConfig.isEmpty) {
      debugPrint('❌ [VPN] Configuración vacía.');
      return VpnConnectResult.tunnelFailed;
    }

    String? username;
    String? password;
    if (node.provider == VpnProvider.proton) {
      // Credenciales: .env, o las del bloque inline del .ovpn si faltan.
      var user = kTunnelUsername.trim();
      var pass = kTunnelPassword.trim();
      final inlineAuth = RegExp(
        r'<auth-user-pass>\s*([^\s<]+)\s+([^\s<]+)\s*</auth-user-pass>',
      ).firstMatch(ovpnConfig);
      if (user.isEmpty && inlineAuth != null) {
        user = inlineAuth.group(1)!.trim();
      }
      if (pass.isEmpty && inlineAuth != null) {
        pass = inlineAuth.group(2)!.trim();
      }
      if (user.isEmpty || pass.isEmpty) {
        debugPrint('❌ [VPN] Credenciales de túnel vacías.');
        return VpnConnectResult.tunnelFailed;
      }
      // Proton: sin +b:N la salida NO es México y verifyConnection falla.
      username = _ensureMexicoExitUsername(user);
      password = pass;
      debugPrint('🔒 [VPN] Usuario de salida MX aplicado (sufijo +b).');

      ovpnConfig = ovpnConfig.replaceAll(
        RegExp(r'<auth-user-pass>[\s\S]*?</auth-user-pass>'),
        'auth-user-pass',
      );
    }
    ovpnConfig = _ensureDataCiphers(ovpnConfig);

    onStatusUpdate?.call(LocaleKeys.loading_connecting_server);

    // Escuchar etapas ANTES de connect. El plugin, si necesita permiso, muestra
    // el diálogo y NO completa el Future de connect; al aceptar, MainActivity
    // llama connectWhileGranted con la config ya guardada.
    final completer = Completer<bool>();
    late StreamSubscription<VPNStage> sub;
    var connectionAttemptStarted = false;
    final connectCallAt = DateTime.now();
    DateTime? attemptStartedAt;
    Timer? connectDeadline;

    void finish(bool value) {
      connectDeadline?.cancel();
      if (!completer.isCompleted) completer.complete(value);
    }

    void armConnectDeadline() {
      connectDeadline?.cancel();
      connectDeadline = Timer(timeout, () {
        debugPrint(
          '⚠️ [VPN] Timeout de conexión (${timeout.inSeconds}s tras start).',
        );
        finish(_currentStage == VPNStage.connected);
      });
    }

    // Sin permiso, Android muestra su diálogo y se espera al usuario sin
    // límite. Con permiso ya concedido no hay nada que esperar: si el túnel no
    // arranca en `timeout`, el pedido se perdió y se pasa al siguiente nodo.
    final permissionDeadline = _androidVpnPermissionGranted == true
        ? Timer(timeout, () {
            if (!connectionAttemptStarted) {
              debugPrint(
                '⚠️ [VPN] El túnel no arrancó (${timeout.inSeconds}s).',
              );
              finish(false);
            }
          })
        : null;

    sub = stageStream.listen((stage) {
      debugPrint('🔒 [VPN Stage Event] Recibido: $stage');
      if (_connectCancelled &&
          (stage == VPNStage.disconnected || stage == VPNStage.error)) {
        finish(false);
        return;
      }
      if (stage == VPNStage.connected) {
        _androidVpnPermissionGranted = true;
        finish(true);
      } else if (stage == VPNStage.authenticating ||
          stage == VPNStage.vpn_generate_config ||
          stage == VPNStage.tcp_connect ||
          stage == VPNStage.connecting ||
          stage == VPNStage.wait_connection) {
        if (!connectionAttemptStarted) {
          connectionAttemptStarted = true;
          attemptStartedAt = DateTime.now();
          permissionDeadline?.cancel();
          onStatusUpdate?.call(LocaleKeys.loading_connecting_server);
          armConnectDeadline();
          debugPrint(
            '🔒 [VPN] Handshake iniciado '
            '(+${attemptStartedAt!.difference(connectCallAt).inMilliseconds}ms).',
          );
        }
      } else if (connectionAttemptStarted &&
          (stage == VPNStage.disconnected || stage == VPNStage.error)) {
        debugPrint('⚠️ [VPN] Conexión no establecida (estado: $stage)');
        finish(false);
      }
    });

    try {
      // Proton: setenv CLIENT_CERT 0 — sin certificado de cliente. VPN Gate
      // autentica con el certificado del .ovpn (certIsRequired).
      // Si hace falta permiso, el plugin guarda config y abre el diálogo del SO.
      unawaited(_engine!
          .connect(
            ovpnConfig,
            'Moai',
            username: username ?? '',
            password: password ?? '',
            certIsRequired: node.provider == VpnProvider.vpnGate,
          )
          .catchError((e) {
            debugPrint('❌ [VPN] Excepción en invocación connect: $e');
          }));
    } catch (e) {
      debugPrint('❌ [VPN] Excepción sincrónica al invocar connect: $e');
      permissionDeadline?.cancel();
      await sub.cancel();
      return VpnConnectResult.tunnelFailed;
    }

    final cancelWatch = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_connectCancelled) finish(false);
    });

    final connected = await completer.future;
    permissionDeadline?.cancel();
    connectDeadline?.cancel();
    cancelWatch.cancel();
    await sub.cancel();
    if (_androidVpnPermissionGranted == false) {
      return VpnConnectResult.permissionDenied;
    }
    if (_connectCancelled) return VpnConnectResult.cancelled;
    if (!connected) return VpnConnectResult.tunnelFailed;

    onStatusUpdate?.call(LocaleKeys.loading_verifying_connection);
    final verified = await verifyConnection(country: node.country);
    debugPrint(
      '🔒 [VPN] Verificación ${node.country}: $verified '
      '(ip=$_lastExitIp cc=$_lastExitCountry)',
    );
    if (verified) return VpnConnectResult.connected;
    // Túnel arriba pero salida incorrecta: soltar antes de rotar nodo.
    await disconnect();
    return VpnConnectResult.wrongCountry;
  }

  /// Verifica que la salida pública sea de [country] (el servicio de catálogo
  /// solo acepta ciertos países).
  Future<bool> verifyConnection({
    required String country,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final res =
          await http.get(Uri.parse('http://ip-api.com/json')).timeout(timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final countryName = data['country'] ?? '';
        final countryCode =
            data['countryCode']?.toString().toUpperCase() ?? '';
        final query = data['query'] ?? '';
        _lastExitIp = query.toString();
        _lastExitCountry = countryCode;
        debugPrint(
          '🌐 [VPN IP Check] IP pública: $query ($countryName, $countryCode)',
        );
        if (countryCode == country) return true;
        debugPrint(
          '⚠️ [VPN IP Check] Salida no es $country ($countryCode).',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [VPN IP Check] ip-api falló: $e');
    }

    try {
      final res = await http
          .get(Uri.parse('https://cloudflare.com/cdn-cgi/trace'))
          .timeout(timeout);
      if (res.statusCode == 200) {
        final loc =
            RegExp(r'loc=([A-Z]+)').firstMatch(res.body)?.group(1) ?? '';
        final ip =
            RegExp(r'ip=([^\n]+)').firstMatch(res.body)?.group(1) ?? '';
        if (ip.isNotEmpty) _lastExitIp = ip;
        if (loc.isNotEmpty) _lastExitCountry = loc;
        debugPrint('🌐 [VPN CF Check] ip=$ip loc=$loc');
        if (loc == country) return true;
        debugPrint('⚠️ [VPN CF Check] Salida no es $country ($loc).');
      }
    } catch (e) {
      debugPrint('⚠️ [VPN CF Check] falló: $e');
    }

    return false;
  }

  /// Desconecta la VPN de forma segura
  Future<void> disconnect({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (_engine == null) return;

    try {
      debugPrint('🔒 [VPN] Desconectando VPN...');
      _engine!.disconnect();

      // Esperar brevemente a que pase a disconnected
      final completer = Completer<void>();
      late StreamSubscription<VPNStage> sub;

      final timer = Timer(timeout, () {
        if (!completer.isCompleted) completer.complete();
      });

      sub = stageStream.listen((stage) {
        if (stage == VPNStage.disconnected) {
          timer.cancel();
          if (!completer.isCompleted) completer.complete();
        }
      });

      if (_currentStage == VPNStage.disconnected) {
        timer.cancel();
        unawaited(sub.cancel());
        return;
      }

      await completer.future;
      await sub.cancel();
      // El proceso de OpenVPN termina ~150 ms después de `disconnected`; un
      // connect antes de eso se pierde sin emitir ninguna etapa.
      await Future<void>.delayed(const Duration(milliseconds: 600));
    } catch (e) {
      debugPrint('⚠️ [VPN] Error al desconectar: $e');
    }
  }


  void dispose() {
    _stageController.close();
  }
}
