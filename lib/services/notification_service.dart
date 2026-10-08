import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'permission_service.dart';

class AppNotificationItem {
  final String id;
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final DateTime timestamp;
  bool isRead;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    required this.timestamp,
    this.isRead = false,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  bool lowStockEnabled = true;
  bool orderChimeEnabled = true;
  bool promoAlertsEnabled = true;

  // In-app notifications history list
  final ValueNotifier<List<AppNotificationItem>> notificationsNotifier =
      ValueNotifier<List<AppNotificationItem>>([]);

  int get unreadCount => notificationsNotifier.value.where((n) => !n.isRead).length;

  /// Initialize system notification channel & plugins
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Request Phone Notifications Permission
      await PermissionService().requestNotificationPermission();

      // 2. Configure Android Notification Settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // 3. Configure iOS / Darwin Notification Settings
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      // Create Android Notification Channel
      if (!kIsWeb) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          const AndroidNotificationChannel channel = AndroidNotificationChannel(
            'pos_alerts_channel',
            'POS Store Notifications',
            description: 'Alerts for orders, stock levels, and store updates',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          );
          await androidPlugin.createNotificationChannel(channel);
        }
      }

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully.');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Sends a native push notification directly to the phone's system notification bar
  Future<void> sendSystemNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'pos_alerts_channel',
        'POS Store Notifications',
        channelDescription: 'Alerts for orders, stock levels, and store updates',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to send system notification: $e');
    }
  }

  /// Record an in-app notification item to the in-app notification center
  void _recordInAppNotification({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    final newItem = AppNotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      icon: icon,
      color: color,
      timestamp: DateTime.now(),
    );

    notificationsNotifier.value = [newItem, ...notificationsNotifier.value];
  }

  void markAllAsRead() {
    for (var item in notificationsNotifier.value) {
      item.isRead = true;
    }
    notificationsNotifier.value = List.from(notificationsNotifier.value);
  }

  void clearAll() {
    notificationsNotifier.value = [];
  }

  /// Show floating in-app snackbar
  void showInAppSnackbar({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    Color backgroundColor = const Color(0xFF0F172A),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Trigger order completion notification to phone notification bar & in-app inbox
  void triggerOrderCompletionNotification(BuildContext? context, double total, {String? orderId}) {
    if (!orderChimeEnabled) return;

    const title = 'Order Completed Successfully! 🎉';
    final message = 'Receipt generated • Total LKR ${total.toStringAsFixed(2)}';

    // 1. Send to Phone System Notification Bar
    sendSystemNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: message,
      payload: orderId ?? 'order',
    );

    // 2. Add to in-app history
    _recordInAppNotification(
      title: title,
      message: message,
      icon: Icons.receipt_long_rounded,
      color: const Color(0xFF16A34A),
    );

    // 3. Show in-app snackbar if context is provided
    if (context != null) {
      showInAppSnackbar(
        context: context,
        title: title,
        message: message,
        icon: Icons.check_circle_rounded,
        backgroundColor: const Color(0xFF166534),
      );
    }
  }

  /// Trigger low stock warning to phone notification bar & in-app inbox
  void triggerLowStockAlert(BuildContext? context, String productName, int stock) {
    if (!lowStockEnabled) return;

    const title = 'Low Stock Alert ⚠️';
    final message = '$productName has only $stock items left in stock!';

    // 1. Send to Phone System Notification Bar
    sendSystemNotification(
      id: (productName.hashCode & 0x7FFFFFFF),
      title: title,
      body: message,
      payload: 'low_stock',
    );

    // 2. Add to in-app history
    _recordInAppNotification(
      title: title,
      message: message,
      icon: Icons.warning_amber_rounded,
      color: const Color(0xFFEF4444),
    );

    // 3. Show in-app snackbar if context is provided
    if (context != null) {
      showInAppSnackbar(
        context: context,
        title: title,
        message: message,
        icon: Icons.warning_amber_rounded,
        backgroundColor: const Color(0xFF991B1B),
      );
    }
  }

  /// Trigger promo alert to phone notification bar & in-app inbox
  void triggerPromoAlert(BuildContext? context, String productName, double original, double discount) {
    if (!promoAlertsEnabled) return;

    final saveAmount = original - discount;
    const title = 'Special Promotion Active 🏷️';
    final message = '$productName is now LKR ${discount.toStringAsFixed(0)} (Save LKR ${saveAmount.toStringAsFixed(0)})!';

    // 1. Send to Phone System Notification Bar
    sendSystemNotification(
      id: (productName.hashCode & 0x7FFFFFFF) + 1,
      title: title,
      body: message,
      payload: 'promo',
    );

    // 2. Add to in-app history
    _recordInAppNotification(
      title: title,
      message: message,
      icon: Icons.local_offer_rounded,
      color: const Color(0xFF2563EB),
    );

    // 3. Show in-app snackbar if context is provided
    if (context != null) {
      showInAppSnackbar(
        context: context,
        title: title,
        message: message,
        icon: Icons.local_offer_rounded,
        backgroundColor: const Color(0xFF1E40AF),
      );
    }
  }

  /// Trigger offline sync completion alert
  void triggerSyncNotification({required int count, String? details}) {
    const title = 'Cloud Sync Complete ☁️';
    final message = details ?? '$count offline records synced with backend server.';

    // 1. Send to Phone System Notification Bar
    sendSystemNotification(
      id: 9991,
      title: title,
      body: message,
      payload: 'sync',
    );

    // 2. Add to in-app history
    _recordInAppNotification(
      title: title,
      message: message,
      icon: Icons.cloud_done_rounded,
      color: const Color(0xFF0284C7),
    );
  }

  /// Trigger Bluetooth printer connection status alert
  void triggerBluetoothNotification({required String printerName, required bool connected}) {
    final title = connected ? 'Bluetooth Printer Connected 🖨️' : 'Bluetooth Printer Disconnected';
    final message = connected ? 'Ready to print receipts on $printerName' : 'Printer was disconnected';

    // 1. Send to Phone System Notification Bar
    sendSystemNotification(
      id: 9992,
      title: title,
      body: message,
      payload: 'bluetooth',
    );

    // 2. Add to in-app history
    _recordInAppNotification(
      title: title,
      message: message,
      icon: Icons.print_rounded,
      color: connected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
    );
  }
}
