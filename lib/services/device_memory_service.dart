import 'dart:io';
import 'package:flutter/services.dart';

class DeviceMemoryService {
  static const MethodChannel _channel =
      MethodChannel('com.infomak.moai.tv/device');

  /// Fallback when platform channel is unavailable (emulator, desktop, error).
  static const int fallbackRamMb = 2048;

  static bool? _isEmulatorCache;

  static Future<int> getTotalRamMb() async {
    if (!Platform.isAndroid) {
      return fallbackRamMb;
    }
    try {
      final result = await _channel.invokeMethod<int>('getTotalRamMb');
      if (result != null && result > 0) {
        return result;
      }
    } catch (_) {
      // Ignored — use fallback.
    }
    return fallbackRamMb;
  }

  static Future<bool> isEmulator() async {
    if (_isEmulatorCache != null) {
      return _isEmulatorCache!;
    }
    if (!Platform.isAndroid) {
      _isEmulatorCache = false;
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('isEmulator');
      _isEmulatorCache = result ?? false;
    } catch (_) {
      _isEmulatorCache = false;
    }
    return _isEmulatorCache!;
  }
}

