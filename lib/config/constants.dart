import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const String kAppName = 'Moai';

// DESARROLLO: en false el arranque salta el login (VPN + sesión + descarga
// del catálogo) y las pausas de la pantalla de carga, para iniciar rápido.
// Usa el catálogo ya guardado; sin sesión, las películas pueden no
// reproducirse. ⚠️ Volver a true antes de sacar un release (de todos modos
// un build release siempre hace el login, ver [kStartupLoginEnabled]).
const bool _kStartupLoginInDebug = false;

/// Si el arranque hace el login. Siempre true en release.
const bool kStartupLoginEnabled = kReleaseMode || _kStartupLoginInDebug;

// Configuración de Caché de Imágenes (Optimizado para Smart TV)
const int kImageCacheMaximumSize = 100;
const int kImageCacheMaximumSizeBytes = 30 * 1024 * 1024; // 30 MB máx RAM

// Hosts con validación TLS estricta (SPEC-50 §2.2). El resto (streams, logos,
// scrapers de plugins) acepta certificados inválidos. Se compara el dominio
// exacto o un subdominio.
const List<String> kStrictSslHosts = [
  // Identidad, presencia y amigos.
  'supabase.co',
  // APK de actualización, manifiestos de plugins, ROMs y core de Arcade.
  'github.com',
  'githubusercontent.com',
  'weatherapi.com',
  'jolpi.ca',
  'themoviedb.org',
  'google.com',
  'googleapis.com',
  'googlevideo.com',
  'gstatic.com',
  'torbox.app',
];

/// `true` si [host] es uno de [kStrictSslHosts] o un subdominio.
bool isStrictSslHost(String host) {
  final h = host.toLowerCase();
  return kStrictSslHosts.any((d) => h == d || h.endsWith('.$d'));
}

// Configuración de Localización
const String kTranslationsPath = 'assets/translations';
const List<Locale> kSupportedLocales = [Locale('es')];
const Locale kFallbackLocale = Locale('es');

/// Lee una variable del `.env`; si no está cargado o no existe, usa [fallback].
String _env(String key, String fallback) =>
    dotenv.isInitialized ? (dotenv.env[key] ?? fallback) : fallback;

// Configuración Moiamov (Catálogo y endpoints)
String get kMoiamovBaseUrl => _env('MOIAMOV_BASE_URL', '');
String get kMoiamovPortalKey => _env('MOIAMOV_PORTAL_KEY', '');
String get kMoiamovLocalDocKey => _env('MOIAMOV_LOCAL_DOC_KEY', '');
String get kMoiamovApkPackage => _env('MOIAMOV_APK_PACKAGE', '');
String get kMoiamovApkVer => _env('MOIAMOV_APK_VER', '');
String get kMoiamovSpkgVer => _env('MOIAMOV_SPKG_VER', '');
String get kMoiamovDefaultUserId => _env('MOIAMOV_DEFAULT_USER_ID', '');
String get kMoiamovDefaultUserToken => _env('MOIAMOV_DEFAULT_USER_TOKEN', '');
String get kMoiamovDefaultPortalCode => _env('MOIAMOV_DEFAULT_PORTAL_CODE', '');
String get kMoiamovSnSalt => _env('MOIAMOV_SN_SALT', '');
String get kMoiamovDeviceCipherKey => _env('MOIAMOV_DEVICE_CIPHER_KEY', '');

// Credenciales del túnel de fondo. Viven solo en `.env`.
String get kTunnelUsername => _env('TUNNEL_USER', '');
String get kTunnelPassword => _env('TUNNEL_PASS', '');

// WeatherAPI (clima). Vive solo en `.env`.
String get kWeatherApiKey => _env('WEATHER_API_KEY', '');

// TURN para WebRTC netplay (recomendado fuera de LAN).
String get kTurnUrl => _env('TURN_URL', '');
String get kTurnUsername => _env('TURN_USER', '');
String get kTurnPassword => _env('TURN_PASS', '');

// Paquete local de lectura de documentos de respaldo
String get kMoiamovDocPackage => _env('MOIAMOV_DOC_PACKAGE', '');

// TMDb API Key (v4 read token o v3 key)
String get kTmdbApiKey => _env('TMDB_API_KEY', '');
