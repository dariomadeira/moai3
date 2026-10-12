import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:openvpn_flutter/openvpn_flutter.dart';

/// Servicio centralizado de VPN open source integrado en Moai TV
class VpnService {
  static final VpnService instance = VpnService._internal();

  VpnService._internal();

  OpenVPN? _engine;
  bool _isInitialized = false;
  VPNStage _currentStage = VPNStage.disconnected;
  VpnStatus? _currentStatus;

  final StreamController<VPNStage> _stageController =
      StreamController<VPNStage>.broadcast();

  Stream<VPNStage> get stageStream => _stageController.stream;
  VPNStage get currentStage => _currentStage;
  VpnStatus? get currentStatus => _currentStatus;
  bool get isConnected => _currentStage == VPNStage.connected;

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

  /// Conecta a un nodo de México usando los perfiles dedicados garantizados de Salvavida (Saltamontes).
  Future<bool> connectMexico({
    int nodeIndex = 0,
    Duration timeout = const Duration(seconds: 14),
    void Function(String message)? onStatusUpdate,
  }) async {
    await initialize();

    // 1. Verificar / Solicitar permiso VPN en Android
    try {
      final hasPerm = await _engine?.requestPermissionAndroid() ?? true;
      if (!hasPerm) {
        onStatusUpdate?.call('Por favor autoriza la conexión VPN en pantalla...');
        debugPrint('⚠️ [VPN] Permiso de VPN requerido en Android.');
      }
    } catch (e) {
      debugPrint('⚠️ [VPN] Error al consultar permisos Android: $e');
    }

    // 2. Lista de perfiles de México verificados (Salvavida de Saltamontes)
    final profiles = [
      'assets/vpn/mexico_01.ovpn',
      'assets/vpn/mexico_02.ovpn',
      'assets/vpn/mexico_03.ovpn',
      'assets/vpn/mexico_04.ovpn',
    ];

    final targetProfile = profiles[nodeIndex.clamp(0, profiles.length - 1)];
    onStatusUpdate?.call('Cargando perfil seguro México (${nodeIndex + 1}/${profiles.length})...');
    
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

    // Credenciales oficiales de Salvavida
    String username = 'ZmD8M4lQLcxVOyqu';
    String password = 'hhHnycXrVSvV7QnSbCmPo3OLj3J0fBwh';

    // Limpiar el bloque <auth-user-pass>...</auth-user-pass> y reemplazarlo por la directiva estándar
    ovpnConfig = ovpnConfig.replaceAll(
      RegExp(r'<auth-user-pass>[\s\S]*?</auth-user-pass>'),
      'auth-user-pass',
    );

    onStatusUpdate?.call('Estableciendo túnel seguro a México...');

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
        'Moai Secure MX ${nodeIndex + 1}',
        username: username,
        password: password,
        certIsRequired: true,
      ).catchError((e) {
        debugPrint('❌ [VPN] Excepción en invocación connect: $e');
      });
    } catch (e) {
      debugPrint('❌ [VPN] Excepción sincrónica al invocar connect: $e');
    }

    final connected = await completer.future;
    await sub.cancel();

    if (connected) {
      onStatusUpdate?.call('Verificando conexión del túnel seguro...');
      final verified = await verifyConnection();
      debugPrint('🔒 [VPN] Verificación de salida a Internet: $verified');
      return true;
    }

    return false;
  }

  /// Verifica la conectividad real a través del túnel
  Future<bool> verifyConnection({Duration timeout = const Duration(seconds: 4)}) async {
    try {
      final res = await http.get(Uri.parse('https://www.google.com/generate_204')).timeout(timeout);
      return res.statusCode == 204 || res.statusCode == 200;
    } catch (_) {
      try {
        final res = await http.get(Uri.parse('https://cloudflare.com/cdn-cgi/trace')).timeout(timeout);
        return res.statusCode == 200;
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

  /// Consulta la API pública de VPN Gate para buscar un servidor de México (MX)
  Future<String?> _fetchMexicoNodeFromPublicApi({required Duration timeout}) async {
    final uri = Uri.parse('http://www.vpngate.net/api/iphone/');
    final response = await http.get(uri).timeout(timeout);

    if (response.statusCode != 200) return null;

    final lines = const LineSplitter().convert(response.body);
    for (final line in lines) {
      if (line.startsWith('*') || line.startsWith('#')) continue;
      final parts = line.split(',');
      if (parts.length >= 15) {
        final country = parts[6].trim().toUpperCase();
        if (country == 'MX') {
          final base64Config = parts[14].trim();
          if (base64Config.isNotEmpty) {
            final decoded = utf8.decode(base64.decode(base64Config));
            return decoded;
          }
        }
      }
    }
    return null;
  }

  void dispose() {
    _stageController.close();
  }
}
