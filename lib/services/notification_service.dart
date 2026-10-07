import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  bool lowStockEnabled = true;
  bool orderChimeEnabled = true;
  bool promoAlertsEnabled = true;

  void showNotification({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    Color backgroundColor = Colors.black,
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

  void triggerOrderCompletionNotification(BuildContext context, double total) {
    if (!orderChimeEnabled) return;
    showNotification(
      context: context,
      title: 'Order Completed Successfully! 🎉',
      message: 'Bill printed • Total LKR ${total.toStringAsFixed(2)}',
      icon: Icons.check_circle_rounded,
      backgroundColor: const Color(0xFF166534),
    );
  }

  void triggerLowStockAlert(BuildContext context, String productName, int stock) {
    if (!lowStockEnabled) return;
    showNotification(
      context: context,
      title: 'Low Stock Alert ⚠️',
      message: '$productName has only $stock items left in stock!',
      icon: Icons.warning_amber_rounded,
      backgroundColor: const Color(0xFF991B1B),
    );
  }

  void triggerPromoAlert(BuildContext context, String productName, double original, double discount) {
    if (!promoAlertsEnabled) return;
    final saveAmount = original - discount;
    showNotification(
      context: context,
      title: 'Special Promotion Active 🏷️',
      message: '$productName is now LKR ${discount.toStringAsFixed(0)} (Save LKR ${saveAmount.toStringAsFixed(0)})!',
      icon: Icons.local_offer_rounded,
      backgroundColor: const Color(0xFF1E40AF),
    );
  }
}
