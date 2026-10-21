import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const String kAppName = 'Moai';

// Configuración de Caché de Imágenes (Optimizado para Smart TV)
const int kImageCacheMaximumSize = 100;
const int kImageCacheMaximumSizeBytes = 30 * 1024 * 1024; // 30 MB máx RAM

// Hosts con validación estricta SSL
const List<String> kStrictSslHosts = [
  'themoviedb.org',
  'google',
  'torbox',
];

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
String get kMoiamovDocPackage =>
    _env('MOIAMOV_DOC_PACKAGE', '');

// TMDb API Key (v4 read token o v3 key)
String get kTmdbApiKey => _env('TMDB_API_KEY', '');

