import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

/// Production-Grade Mobile Device Security & Integrity Guard
/// Handles Root / Jailbreak detection, developer mode risks,
/// and prevents screen capture / screen recording on POS terminals.
class SecurityCheckService {
  /// Verify device integrity at startup.
  /// Returns `true` if safe to proceed, or `false` if rooted/compromised.
  static Future<bool> verifyDeviceIntegrity() async {
    // 1. Web browser environment fail-safe (mobile packages not applicable)
    if (kIsWeb) {
      return true;
    }

    try {
      // 2. Check for Rooted (Android) or Jailbroken (iOS) modified system
      if (Platform.isAndroid || Platform.isIOS) {
        final bool isJailbroken = await FlutterJailbreakDetection.jailbroken;
        if (isJailbroken) {
          // High security threat: Rooted/compromised device
          debugPrint('⛔ SECURITY ALERT: Device is Rooted or Jailbroken.');
          return false;
        }

        // 3. Prevent Screenshots & Screen Recording on Android POS devices
        if (Platform.isAndroid) {
          await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
          debugPrint('🛡️ SECURITY: Android FLAG_SECURE screen protection activated.');
        }
      }

      return true;
    } on PlatformException catch (e) {
      debugPrint('⚠️ SecurityCheckService PlatformException: $e');
      // Fail-safe to avoid false positives on legitimate devices
      return true;
    } catch (e) {
      debugPrint('⚠️ SecurityCheckService error: $e');
      return true;
    }
  }

  /// Manually enable or disable screen capture protection (Android only)
  static Future<void> setScreenProtection(bool enable) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      if (enable) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } else {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      }
    } catch (_) {}
  }
}
