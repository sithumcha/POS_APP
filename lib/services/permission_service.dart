import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Request Notification Permission (Android 13+ & iOS)
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Notification permission error: $e');
      return false;
    }
  }

  /// Request Bluetooth Permissions (iOS & Android)
  Future<bool> requestBluetoothPermissions() async {
    if (kIsWeb) return true;
    try {
      // iOS uses Permission.bluetooth
      // Android 12+ requires BLUETOOTH_SCAN, BLUETOOTH_CONNECT, BLUETOOTH_ADVERTISE
      // Older Android requires location
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.locationWhenInUse,
      ].request();

      final bool granted = statuses[Permission.bluetooth]?.isGranted == true ||
          statuses[Permission.bluetoothConnect]?.isGranted == true ||
          statuses[Permission.bluetoothScan]?.isGranted == true ||
          statuses[Permission.locationWhenInUse]?.isGranted == true;

      return granted;
    } catch (e) {
      debugPrint('Bluetooth permission error: $e');
      return false;
    }
  }

  /// Request Camera Permission for Barcode / QR Scanning (iOS & Android)
  Future<bool> requestCameraPermission() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.camera.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Camera permission error: $e');
      return false;
    }
  }

  /// Request Notification, Camera and Bluetooth permissions on startup
  Future<void> requestAllAppPermissions() async {
    if (kIsWeb) return;
    try {
      await requestNotificationPermission();
      await requestCameraPermission();
      await requestBluetoothPermissions();
    } catch (e) {
      debugPrint('Error requesting app permissions: $e');
    }
  }

  /// Check whether notification permission is currently granted
  Future<bool> isNotificationGranted() async {
    if (kIsWeb) return true;
    try {
      return await Permission.notification.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Check whether bluetooth permission is currently granted
  Future<bool> isBluetoothGranted() async {
    if (kIsWeb) return true;
    try {
      final connect = await Permission.bluetoothConnect.isGranted;
      final scan = await Permission.bluetoothScan.isGranted;
      return connect || scan;
    } catch (_) {
      return false;
    }
  }
}
