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

  /// Conecta a un nodo de México usando la API pública con fallback a configuración local garantizada.
  Future<bool> connectMexico({
    Duration timeout = const Duration(seconds: 10),
    void Function(String message)? onStatusUpdate,
  }) async {
    await initialize();

    onStatusUpdate?.call('Consultando red segura (México)...');
    String? ovpnConfig;
    String connectionName = 'Moai Secure Node MX';

    // 1. Intentar obtener nodo de México desde API pública de VPN Gate
    try {
      ovpnConfig = await _fetchMexicoNodeFromPublicApi(
        timeout: const Duration(seconds: 3),
      );
      if (ovpnConfig != null && ovpnConfig.isNotEmpty) {
        debugPrint('🌐 [VPN] Nodo de México obtenido exitosamente desde API pública.');
        onStatusUpdate?.call('Nodo público de México seleccionado...');
      }
    } catch (e) {
      debugPrint('⚠️ [VPN] Error consultando API pública: $e');
    }

    // 2. Si la API pública no tiene nodos MX o falló, usar perfil local verificado
    if (ovpnConfig == null || ovpnConfig.isEmpty) {
      debugPrint('🛡️ [VPN] Usando perfil dedicado de México empaquetado...');
      onStatusUpdate?.call('Conectando a servidor seguro México...');
      try {
        ovpnConfig = await rootBundle.loadString('assets/vpn/mexico_01.ovpn');
      } catch (e) {
        debugPrint('❌ [VPN] Error al cargar assets/vpn/mexico_01.ovpn: $e');
        try {
          ovpnConfig = await rootBundle.loadString('assets/vpn/mexico_02.ovpn');
        } catch (_) {}
      }
    }

    if (ovpnConfig == null || ovpnConfig.isEmpty) {
      debugPrint('❌ [VPN] No se encontró ninguna configuración de VPN disponible.');
      return false;
    }

    onStatusUpdate?.call('Estableciendo túnel seguro (México)...');

    // Extraer credenciales si están en el archivo o conectarse directamente
    String? username;
    String? password;
    final authMatch = RegExp(r'<auth-user-pass>\s*([^\r\n]+)\s*([^\r\n]+)\s*</auth-user-pass>')
        .firstMatch(ovpnConfig);
    if (authMatch != null) {
      username = authMatch.group(1)?.trim();
      password = authMatch.group(2)?.trim();
    }

    try {
      await _engine!.connect(
        ovpnConfig,
        connectionName,
        username: username,
        password: password,
        certIsRequired: true,
      );
    } catch (e) {
      debugPrint('❌ [VPN] Excepción al invocar connect: $e');
      return false;
    }

    // Esperar hasta que esté conectado o venza el timeout
    final completer = Completer<bool>();
    late StreamSubscription<VPNStage> sub;

    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        debugPrint('⚠️ [VPN] Tiempo de espera de conexión agotado (${timeout.inSeconds}s).');
        completer.complete(_currentStage == VPNStage.connected);
      }
    });

    sub = stageStream.listen((stage) {
      if (stage == VPNStage.connected) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete(true);
      } else if (stage == VPNStage.disconnected || stage == VPNStage.error) {
        // En algunas fases iniciales pasa por disconnected antes de wait/auth
      }
    });

    // Si ya estaba conectado inmediatamente
    if (_currentStage == VPNStage.connected) {
      timer.cancel();
      sub.cancel();
      return true;
    }

    final result = await completer.future;
    await sub.cancel();
    return result;
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
