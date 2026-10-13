import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _keyPasswordHash = 'emergency_password_hash';
  static const String _keyIsLocked = 'is_locked';
  static const String _keyLockEndTime = 'lock_end_time';
  static const String _keyBlockedApps = 'blocked_apps';
  static const String _keyWhitelistMode = 'whitelist_mode';
  static const String _keyTotalFocusMinutes = 'total_focus_minutes';
  static const String _keyEmergencyBreaks = 'emergency_breaks_count';

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  /// Acil durum şifresini ayarlar
  static Future<void> setEmergencyPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPasswordHash, hashPassword(password));
  }

  /// Şifre belirlenmiş mi kontrol eder
  static Future<bool> hasPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyPasswordHash);
  }

  /// Girilen şifreyi doğrular
  static Future<bool> verifyPassword(String enteredPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final savedHash = prefs.getString(_keyPasswordHash);
    if (savedHash == null) {
      // Varsayılan şifre yoksa "1234" kabul edilebilir veya şifre yok sayılabilir
      return enteredPassword == "1234";
    }
    return savedHash == hashPassword(enteredPassword);
  }

  /// Kilit modunu başlatır
  static Future<void> startLock({
    required int durationMinutes,
    required List<String> blockedApps,
    required bool whitelistMode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final endTime = DateTime.now().add(Duration(minutes: durationMinutes));
    await prefs.setBool(_keyIsLocked, true);
    await prefs.setInt(_keyLockEndTime, endTime.millisecondsSinceEpoch);
    await prefs.setStringList(_keyBlockedApps, blockedApps);
    await prefs.setBool(_keyWhitelistMode, whitelistMode);
  }

  /// Kilidi kaldırır
  static Future<void> stopLock({bool isEmergency = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLocked, false);
    await prefs.remove(_keyLockEndTime);

    if (isEmergency) {
      int breaks = prefs.getInt(_keyEmergencyBreaks) ?? 0;
      await prefs.setInt(_keyEmergencyBreaks, breaks + 1);
    }
  }

  /// Kilit aktif mi?
  static Future<bool> isCurrentlyLocked() async {
    final prefs = await SharedPreferences.getInstance();
    final locked = prefs.getBool(_keyIsLocked) ?? false;
    if (!locked) return false;

    final endTimeMs = prefs.getInt(_keyLockEndTime) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch >= endTimeMs) {
      // Süre dolmuş, otomatik kilit kaldır
      await stopLock();
      return false;
    }
    return true;
  }

  /// Kalan kilit süresini (saniye) döner
  static Future<int> getRemainingSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final endTimeMs = prefs.getInt(_keyLockEndTime) ?? 0;
    final remaining = (endTimeMs - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
    return remaining > 0 ? remaining : 0;
  }

  /// Engellenen paketleri getirir
  static Future<List<String>> getBlockedApps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyBlockedApps) ?? [];
  }

  /// Beyaz liste modunu getirir
  static Future<bool> isWhitelistMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyWhitelistMode) ?? false;
  }

  /// İstatistikleri artırır
  static Future<void> addFocusTime(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(_keyTotalFocusMinutes) ?? 0;
    await prefs.setInt(_keyTotalFocusMinutes, current + minutes);
  }

  /// İstatistikleri çeker
  static Future<Map<String, int>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'totalMinutes': prefs.getInt(_keyTotalFocusMinutes) ?? 0,
      'emergencyBreaks': prefs.getInt(_keyEmergencyBreaks) ?? 0,
    };
  }
}
