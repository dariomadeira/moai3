import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

export 'package:provider/provider.dart';

/// Extensiones de ayuda para acceso seguro e inyección de dependencias opcionales en [BuildContext].
extension SafeProviderContext on BuildContext {
  /// Escucha un proveedor opcional de forma segura sin lanzar [ProviderNotFoundException].
  T? watchOptional<T>() {
    try {
      return watch<T>();
    } catch (_) {
      return null;
    }
  }

  /// Lee un proveedor opcional de forma segura sin lanzar [ProviderNotFoundException].
  T? readOptional<T>() {
    try {
      return read<T>();
    } catch (_) {
      return null;
    }
  }
}
