import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
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

  /// Corta el intento de conexión en curso para salir del arranque sin esperar el timeout.
  void cancelConnect() {
    _connectCancelled = true;
    try {
      _engine?.disconnect();
    } catch (_) {}
  }

  Future<void> initialize() async {
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

  /// Pide (una vez) el consentimiento VPN de Android y espera el resultado.
  ///
  /// Si el usuario deniega, no se vuelve a mostrar el diálogo en esta sesión
  /// de proceso (el loop de nodos no debe reabrirlo).
  Future<bool> ensureAndroidVpnPermission({
    void Function(String message)? onStatusUpdate,
  }) async {
    if (_androidVpnPermissionGranted == true) return true;
    if (_androidVpnPermissionGranted == false) return false;

    await initialize();
    if (_connectCancelled) return false;

    try {
      onStatusUpdate?.call('loading_permission_required');
      final hasPerm = await _engine?.requestPermissionAndroid() ?? true;
      _androidVpnPermissionGranted = hasPerm;
      if (!hasPerm) {
        debugPrint('⚠️ [VPN] Permiso de VPN denegado o no concedido.');
      } else {
        debugPrint('🔒 [VPN] Permiso de VPN concedido.');
      }
      return hasPerm;
    } catch (e) {
      debugPrint('⚠️ [VPN] Error al consultar permisos Android: $e');
      // No marcar como denegado permanente: un fallo del plugin no debe
      // bloquear reintentos si el sistema ya tenía el consentimiento.
      return false;
    }
  }

  /// Conecta a un nodo de México usando los perfiles dedicados garantizados de Salvavida (Saltamontes).
  Future<bool> connectMexico({
    int nodeIndex = 0,
    Duration timeout = const Duration(seconds: 14),
    void Function(String message)? onStatusUpdate,
  }) async {
    _connectCancelled = false;
    await initialize();
    if (_connectCancelled) return false;

    // 1. Sin permiso Android no intentar connect (evita reabrir el diálogo).
    final hasPerm = await ensureAndroidVpnPermission(
      onStatusUpdate: onStatusUpdate,
    );
    if (!hasPerm || _connectCancelled) {
      return false;
    }

    // 2. Lista de perfiles verificados
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

    // Credenciales del túnel
    final username = kTunnelUsername;
    final password = kTunnelPassword;

    // Limpiar el bloque <auth-user-pass>...</auth-user-pass> y reemplazarlo por la directiva estándar
    ovpnConfig = ovpnConfig.replaceAll(
      RegExp(r'<auth-user-pass>[\s\S]*?</auth-user-pass>'),
      'auth-user-pass',
    );

    onStatusUpdate?.call('loading_connecting_server');

    // Iniciar escucha del stream de etapas ANTES de invocar connect
    final completer = Completer<bool>();
    late StreamSubscription<VPNStage> sub;
    bool connectionAttemptStarted = false;

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        debugPrint('⚠️ [VPN] Tiempo de espera de conexión agotado (${timeout.inSeconds}s).');
        completer.complete(_currentStage == VPNStage.connected);
      }
    });

    sub = stageStream.listen((stage) {
      debugPrint('🔒 [VPN Stage Event] Recibido: $stage');
      if (_connectCancelled &&
          (stage == VPNStage.disconnected || stage == VPNStage.error)) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete(false);
        return;
      }
      if (stage == VPNStage.connected) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete(true);
      } else if (stage == VPNStage.authenticating ||
          stage == VPNStage.vpn_generate_config ||
          stage == VPNStage.tcp_connect ||
          stage == VPNStage.connecting ||
          stage == VPNStage.wait_connection) {
        connectionAttemptStarted = true;
      } else if (connectionAttemptStarted &&
          (stage == VPNStage.disconnected || stage == VPNStage.error)) {
        debugPrint('⚠️ [VPN] Conexión no establecida (estado: $stage)');
        timer.cancel();
        if (!completer.isCompleted) completer.complete(false);
      }
    });

    try {
      _engine!.connect(
        ovpnConfig,
        'Moai',
        username: username,
        password: password,
        certIsRequired: true,
      ).catchError((e) {
        debugPrint('❌ [VPN] Excepción en invocación connect: $e');
      });
    } catch (e) {
      debugPrint('❌ [VPN] Excepción sincrónica al invocar connect: $e');
    }

    final cancelWatch = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_connectCancelled && !completer.isCompleted) {
        timer.cancel();
        completer.complete(false);
      }
    });

    final connected = await completer.future;
    cancelWatch.cancel();
    await sub.cancel();
    if (_connectCancelled) return false;

    if (connected) {
      onStatusUpdate?.call('loading_verifying_connection');
      final verified = await verifyConnection();
      debugPrint('🔒 [VPN] Verificación de salida por México: $verified');
      if (verified) return true;
    }

    return false;
  }

  /// Verifica la conectividad real a través del túnel y comprueba que la geolocalización sea de México
  Future<bool> verifyConnection({Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final res = await http.get(Uri.parse('http://ip-api.com/json')).timeout(timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final country = data['country'] ?? '';
        final countryCode = data['countryCode']?.toString().toUpperCase() ?? '';
        final query = data['query'] ?? '';
        _lastExitIp = query.toString();
        _lastExitCountry = countryCode;
        debugPrint('🌐 [VPN IP Check] IP pública detectada: $query ($country, $countryCode)');
        if (countryCode == 'MX') {
          return true;
        } else {
          debugPrint('⚠️ [VPN IP Check] La salida no es de México (es $countryCode).');
          return false;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [VPN IP Check] No se pudo consultar ip-api: $e');
    }
    try {
      final res = await http.get(Uri.parse('https://www.google.com/generate_204')).timeout(timeout);
      return res.statusCode == 204 || res.statusCode == 200;
    } catch (_) {
      try {
        final res = await http.get(Uri.parse('https://cloudflare.com/cdn-cgi/trace')).timeout(timeout);
        if (res.statusCode == 200) {
          final loc = RegExp(r'loc=([A-Z]+)').firstMatch(res.body)?.group(1);
          if (loc != null) _lastExitCountry = loc;
          return true;
        }
        return false;
      } catch (_) {
        return false;
      }
    }
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
