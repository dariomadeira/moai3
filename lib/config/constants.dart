import 'package:flutter/material.dart';

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

