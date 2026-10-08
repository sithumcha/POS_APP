import 'dart:async';
import 'package:flutter/foundation.dart';
import 'permission_service.dart';
import 'notification_service.dart';

class BluetoothPrinterService {
  static final BluetoothPrinterService _instance = BluetoothPrinterService._internal();
  factory BluetoothPrinterService() => _instance;
  BluetoothPrinterService._internal();

  Map<String, String>? _connectedDevice;
  bool _isScanning = false;

  Map<String, String>? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;
  bool get isScanning => _isScanning;

  // Mock list of discovered & paired Bluetooth printers
  final List<Map<String, String>> _availableDevices = [
    {
      'name': 'POS-58 Thermal Printer',
      'address': '00:11:22:33:44:55',
      'type': 'Bluetooth 4.0 / Classic',
    },
    {
      'name': 'PT-210 Mobile Printer',
      'address': '88:66:22:11:99:33',
      'type': 'Bluetooth 4.0',
    },
    {
      'name': 'RPP02N ESC/POS Printer',
      'address': 'AA:BB:CC:DD:EE:FF',
      'type': 'Bluetooth Classic',
    },
  ];

  List<Map<String, String>> get availableDevices => List.unmodifiable(_availableDevices);

  Future<List<Map<String, String>>> scanDevices() async {
    // Request Bluetooth and Location permission before scanning
    await PermissionService().requestBluetoothPermissions();

    _isScanning = true;
    await Future.delayed(const Duration(seconds: 2));
    _isScanning = false;
    return _availableDevices;
  }

  Future<bool> connectDevice(Map<String, String> device) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _connectedDevice = device;
    NotificationService().triggerBluetoothNotification(
      printerName: device['name'] ?? 'Thermal Printer',
      connected: true,
    );
    return true;
  }

  Future<void> disconnectDevice() async {
    final name = _connectedDevice?['name'] ?? 'Thermal Printer';
    await Future.delayed(const Duration(milliseconds: 300));
    _connectedDevice = null;
    NotificationService().triggerBluetoothNotification(
      printerName: name,
      connected: false,
    );
  }

  /// Format receipt text for 58mm Thermal Printer (32 Characters width per line)
  String generateThermalReceiptText({
    required String storeName,
    required String cashierName,
    required String receiptNumber,
    required DateTime dateTime,
    required List<Map<String, dynamic>> orderItems,
    required double subtotal,
    required double discountAmount,
    required double grandTotal,
    required String paymentMethod,
    required double cashTendered,
    required double changeDue,
  }) {
    final StringBuffer sb = StringBuffer();

    String center(String text, {int width = 32}) {
      if (text.length >= width) return text.substring(0, width);
      final pad = (width - text.length) ~/ 2;
      return ' ' * pad + text;
    }

    String twoColumn(String left, String right, {int width = 32}) {
      final totalLen = left.length + right.length;
      if (totalLen >= width) {
        final maxLeft = width - right.length - 1;
        final truncatedLeft = left.length > maxLeft ? left.substring(0, maxLeft) : left;
        final spaces = width - truncatedLeft.length - right.length;
        return truncatedLeft + (' ' * (spaces > 0 ? spaces : 1)) + right;
      }
      final spaces = width - totalLen;
      return left + (' ' * spaces) + right;
    }

    final divider = '-' * 32;

    sb.writeln(center(storeName.toUpperCase()));
    sb.writeln(center('POS RECEIPT'));
    sb.writeln(divider);
    sb.writeln(twoColumn('Receipt #:', receiptNumber));
    sb.writeln(twoColumn('Date:', '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}'));
    sb.writeln(twoColumn('Cashier:', cashierName));
    sb.writeln(divider);
    sb.writeln(twoColumn('ITEM', 'QTY x PRICE   TOTAL'));
    sb.writeln(divider);

    for (var item in orderItems) {
      final name = (item['name'] ?? 'Item').toString();
      final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      final unitPrice = double.tryParse((item['price'] ?? item['unit_price'] ?? 0.0).toString()) ?? 0.0;
      final totalPrice = double.tryParse((item['total_price'] ?? (unitPrice * qty)).toString()) ?? (unitPrice * qty);

      sb.writeln(name);
      final priceDetail = '$qty x ${unitPrice.toStringAsFixed(2)}';
      final totalStr = 'LKR ${totalPrice.toStringAsFixed(2)}';
      sb.writeln(twoColumn('  $priceDetail', totalStr));
    }

    sb.writeln(divider);
    sb.writeln(twoColumn('Subtotal:', 'LKR ${subtotal.toStringAsFixed(2)}'));
    if (discountAmount > 0) {
      sb.writeln(twoColumn('Discount:', '-LKR ${discountAmount.toStringAsFixed(2)}'));
    }
    sb.writeln(divider);
    sb.writeln(twoColumn('TOTAL:', 'LKR ${grandTotal.toStringAsFixed(2)}'));
    sb.writeln(twoColumn('Paid via:', paymentMethod));
    if (paymentMethod == 'Cash' && cashTendered > 0) {
      sb.writeln(twoColumn('Cash Tendered:', 'LKR ${cashTendered.toStringAsFixed(2)}'));
      sb.writeln(twoColumn('Change Due:', 'LKR ${changeDue.toStringAsFixed(2)}'));
    }
    sb.writeln(divider);
    sb.writeln(center('THANK YOU FOR YOUR PURCHASE!'));
    sb.writeln(center('Powered by POS App'));
    sb.writeln('\n\n'); // Feed lines for thermal cutter

    return sb.toString();
  }

  Future<bool> printReceiptData({
    required String storeName,
    required String cashierName,
    required String receiptNumber,
    required DateTime dateTime,
    required List<Map<String, dynamic>> orderItems,
    required double subtotal,
    required double discountAmount,
    required double grandTotal,
    required String paymentMethod,
    required double cashTendered,
    required double changeDue,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final text = generateThermalReceiptText(
      storeName: storeName,
      cashierName: cashierName,
      receiptNumber: receiptNumber,
      dateTime: dateTime,
      orderItems: orderItems,
      subtotal: subtotal,
      discountAmount: discountAmount,
      grandTotal: grandTotal,
      paymentMethod: paymentMethod,
      cashTendered: cashTendered,
      changeDue: changeDue,
    );

    if (kDebugMode) {
      debugPrint('=== BLUETOOTH ESC/POS RECEIPT DATA ===');
      debugPrint(text);
    }
    return true;
  }
}
