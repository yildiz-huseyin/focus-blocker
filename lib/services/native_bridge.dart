import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.example.focus_blocker/native_blocker');

  /// Kilit durumunu native servise bildirir
  static Future<bool> setLockStatus({
    required bool isLocked,
    required bool whitelistMode,
    required List<String> blockedPackages,
  }) async {
    try {
      final bool? result = await _channel.invokeMethod('setLockStatus', {
        'isLocked': isLocked,
        'whitelistMode': whitelistMode,
        'blockedPackages': blockedPackages,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Gerekli izinlerin (Overlay & Accessibility) durumunu denetler
  static Future<Map<String, bool>> checkPermissions() async {
    try {
      final Map<dynamic, dynamic>? res = await _channel.invokeMethod('checkPermissions');
      if (res != null) {
        return {
          'overlay': res['overlay'] as bool? ?? false,
          'accessibility': res['accessibility'] as bool? ?? false,
        };
      }
    } on PlatformException {
      // Fallback
    }
    return {'overlay': false, 'accessibility': false};
  }

  /// Overlay izni isteme ekranını açar
  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  /// Erişilebilirlik ayarları ekranını açar
  static Future<void> requestAccessibilityPermission() async {
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
    } catch (_) {}
  }

  /// Cihazda yüklü uygulamaları getirir
  static Future<List<Map<String, String>>> getInstalledApps() async {
    try {
      final List<dynamic>? apps = await _channel.invokeMethod('getInstalledApps');
      if (apps != null) {
        return apps.map((app) {
          final map = app as Map<dynamic, dynamic>;
          return {
            'appName': map['appName'].toString(),
            'packageName': map['packageName'].toString(),
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }
}
