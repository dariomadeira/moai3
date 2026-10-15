import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel, rootBundle;
import 'package:http/http.dart' as http;
import 'package:openvpn_flutter/openvpn_flutter.dart';
import '../config/constants.dart';

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
      MethodChannel('com.infomak.moai.tv/vpn_permission');

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
    if (_androidVpnPermissionGranted == true) return;
    onStatusUpdate?.call('loading_permission_required');
  }

  /// Conecta a un nodo de México usando los perfiles dedicados garantizados de Salvavida (Saltamontes).
  Future<bool> connectMexico({
    int nodeIndex = 0,
    Duration timeout = const Duration(seconds: 14),
    /// Tiempo extra mientras el sistema muestra el aviso VPN (primera vez).
    Duration permissionWait = const Duration(seconds: 120),
    void Function(String message)? onStatusUpdate,
  }) async {
    _connectCancelled = false;
    await initialize();
    if (_androidVpnPermissionGranted == false) {
      debugPrint('⚠️ [VPN] Permiso ya denegado en esta sesión.');
      return false;
    }
    if (_connectCancelled) return false;

    await prepareAndroidVpnPermissionUi(onStatusUpdate: onStatusUpdate);
    if (_connectCancelled) return false;

    final profiles = [
      'assets/vpn/mexico_01.ovpn',
      'assets/vpn/mexico_02.ovpn',
      'assets/vpn/mexico_03.ovpn',
      'assets/vpn/mexico_04.ovpn',
    ];

    final targetProfile = profiles[nodeIndex.clamp(0, profiles.length - 1)];
    onStatusUpdate?.call('loading_init_services');

    String? ovpnConfig;
    try {
      ovpnConfig = await rootBundle.loadString(targetProfile);
    } catch (e) {
      debugPrint('❌ [VPN] Error al cargar $targetProfile: $e');
      ovpnConfig = await rootBundle.loadString('assets/vpn/mexico_01.ovpn');
    }

    if (ovpnConfig.isEmpty) {
      debugPrint('❌ [VPN] Configuración vacía.');
      return false;
    }

    // Credenciales: .env, o las del bloque inline del .ovpn si faltan.
    var username = kTunnelUsername.trim();
    var password = kTunnelPassword.trim();
    final inlineAuth = RegExp(
      r'<auth-user-pass>\s*([^\s<]+)\s+([^\s<]+)\s*</auth-user-pass>',
    ).firstMatch(ovpnConfig);
    if (username.isEmpty && inlineAuth != null) {
      username = inlineAuth.group(1)!.trim();
    }
    if (password.isEmpty && inlineAuth != null) {
      password = inlineAuth.group(2)!.trim();
    }
    if (username.isEmpty || password.isEmpty) {
      debugPrint('❌ [VPN] Credenciales de túnel vacías.');
      return false;
    }

    // Proton: sin +b:N la salida NO es México y verifyConnection falla.
    username = _ensureMexicoExitUsername(username);
    debugPrint('🔒 [VPN] Usuario de salida MX aplicado (sufijo +b).');

    ovpnConfig = ovpnConfig.replaceAll(
      RegExp(r'<auth-user-pass>[\s\S]*?</auth-user-pass>'),
      'auth-user-pass',
    );
    ovpnConfig = _ensureDataCiphers(ovpnConfig);

    onStatusUpdate?.call('loading_connecting_server');

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

    final permissionDeadline = Timer(permissionWait, () {
      if (!connectionAttemptStarted) {
        debugPrint(
          '⚠️ [VPN] Timeout esperando permiso/inicio '
          '(${permissionWait.inSeconds}s).',
        );
        finish(false);
      }
    });

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
          permissionDeadline.cancel();
          onStatusUpdate?.call('loading_connecting_server');
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
      // Proton/MX: setenv CLIENT_CERT 0 — sin certificado de cliente.
      // Si hace falta permiso, el plugin guarda config y abre el diálogo del SO.
      _engine!
          .connect(
            ovpnConfig,
            'Moai',
            username: username,
            password: password,
            certIsRequired: false,
          )
          .catchError((e) {
            debugPrint('❌ [VPN] Excepción en invocación connect: $e');
          });
    } catch (e) {
      debugPrint('❌ [VPN] Excepción sincrónica al invocar connect: $e');
      permissionDeadline.cancel();
      await sub.cancel();
      return false;
    }

    final cancelWatch = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_connectCancelled) finish(false);
    });

    final connected = await completer.future;
    permissionDeadline.cancel();
    connectDeadline?.cancel();
    cancelWatch.cancel();
    await sub.cancel();
    if (_connectCancelled) return false;

    if (connected) {
      onStatusUpdate?.call('loading_verifying_connection');
      final verified = await verifyConnection();
      debugPrint(
        '🔒 [VPN] Verificación México: $verified '
        '(ip=$_lastExitIp cc=$_lastExitCountry)',
      );
      if (verified) return true;
      // Túnel arriba pero salida incorrecta: soltar antes de rotar nodo.
      await disconnect();
    }

    return false;
  }

  /// Verifica salida pública por México (obligatorio para Moiamov).
  Future<bool> verifyConnection({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final res =
          await http.get(Uri.parse('http://ip-api.com/json')).timeout(timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final country = data['country'] ?? '';
        final countryCode =
            data['countryCode']?.toString().toUpperCase() ?? '';
        final query = data['query'] ?? '';
        _lastExitIp = query.toString();
        _lastExitCountry = countryCode;
        debugPrint(
          '🌐 [VPN IP Check] IP pública: $query ($country, $countryCode)',
        );
        if (countryCode == 'MX') return true;
        debugPrint(
          '⚠️ [VPN IP Check] Salida no es México ($countryCode). '
          'Revisá sufijo +b:0 en el usuario OpenVPN.',
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
        if (loc == 'MX') return true;
        debugPrint('⚠️ [VPN CF Check] Salida no es México ($loc).');
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
        sub.cancel();
        return;
      }

      await completer.future;
      await sub.cancel();
    } catch (e) {
      debugPrint('⚠️ [VPN] Error al desconectar: $e');
    }
  }


  void dispose() {
    _stageController.close();
  }
}
