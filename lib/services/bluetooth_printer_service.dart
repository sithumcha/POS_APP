import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'permission_service.dart';
import 'notification_service.dart';

class BluetoothPrinterService {
  static final BluetoothPrinterService _instance = BluetoothPrinterService._internal();
  factory BluetoothPrinterService() => _instance;
  BluetoothPrinterService._internal() {
    loadSavedDevices();
  }

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _storageKeyPrinters = 'saved_bluetooth_printers';
  static const String _storageKeyConnected = 'last_connected_printer_address';

  Map<String, String>? _connectedDevice;
  bool _isScanning = false;
  final List<Map<String, String>> _availableDevices = [];
  bool _isInitialized = false;

  Map<String, String>? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;
  bool get isScanning => _isScanning;

  List<Map<String, String>> get availableDevices => List.unmodifiable(_availableDevices);

  /// Load dynamically saved paired Bluetooth printers from secure storage
  Future<void> loadSavedDevices() async {
    try {
      final raw = await _storage.read(key: _storageKeyPrinters);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        _availableDevices.clear();
        for (var item in decoded) {
          if (item is Map) {
            _availableDevices.add(item.map((k, v) => MapEntry(k.toString(), v.toString())));
          }
        }
      }
      final lastAddr = await _storage.read(key: _storageKeyConnected);
      if (lastAddr != null && lastAddr.isNotEmpty) {
        final match = _availableDevices.where((d) => d['address'] == lastAddr);
        if (match.isNotEmpty) {
          _connectedDevice = match.first;
        }
      }
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading saved bluetooth printers: $e');
      }
    }
  }

  /// Persist the current dynamic printer list to storage
  Future<void> _persistDevices() async {
    try {
      await _storage.write(key: _storageKeyPrinters, value: jsonEncode(_availableDevices));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error persisting bluetooth printers: $e');
      }
    }
  }

  /// Dynamically add or update a paired printer
  Future<void> saveDevice(Map<String, String> device) async {
    final addr = device['address'] ?? '';
    if (addr.isEmpty) return;
    final index = _availableDevices.indexWhere((d) => d['address'] == addr);
    if (index >= 0) {
      _availableDevices[index] = device;
    } else {
      _availableDevices.add(device);
    }
    await _persistDevices();
  }

  /// Remove a printer from the saved list
  Future<void> removeDevice(String address) async {
    if (_connectedDevice?['address'] == address) {
      await disconnectDevice();
    }
    _availableDevices.removeWhere((d) => d['address'] == address);
    await _persistDevices();
  }

  /// Scan for real paired Bluetooth thermal printers dynamically using native driver
  Future<List<Map<String, String>>> scanDevices() async {
    // Request Bluetooth and Location permission before scanning
    await PermissionService().requestBluetoothPermissions();

    _isScanning = true;
    if (!_isInitialized) {
      await loadSavedDevices();
    }

    // On mobile platforms, query native paired Bluetooth printers
    if (!kIsWeb) {
      try {
        final bool isGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
        if (isGranted) {
          final List<BluetoothInfo> paired = await PrintBluetoothThermal.pairedBluetooths;
          for (final p in paired) {
            final name = (p.name.isNotEmpty) ? p.name : 'Bluetooth Thermal Printer';
            final mac = p.macAdress;
            if (mac.isNotEmpty) {
              await saveDevice({
                'name': name,
                'address': mac,
                'type': 'Bluetooth ESC/POS',
              });
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Bluetooth hardware paired scan error: $e');
        }
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 800));
    }

    _isScanning = false;
    return List.unmodifiable(_availableDevices);
  }

  /// Connect to physical Bluetooth thermal printer via MAC address
  Future<bool> connectDevice(Map<String, String> device) async {
    final macAddress = device['address'] ?? '';
    bool success = false;

    if (!kIsWeb && macAddress.isNotEmpty) {
      try {
        success = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Hardware Bluetooth connection error: $e');
        }
        success = false;
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
      success = true;
    }

    if (success) {
      _connectedDevice = device;
      if (macAddress.isNotEmpty) {
        await _storage.write(key: _storageKeyConnected, value: macAddress);
      }
      NotificationService().triggerBluetoothNotification(
        printerName: device['name'] ?? 'Thermal Printer',
        connected: true,
      );
    }

    return success;
  }

  /// Disconnect active Bluetooth thermal printer
  Future<void> disconnectDevice() async {
    final name = _connectedDevice?['name'] ?? 'Thermal Printer';

    if (!kIsWeb) {
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Hardware Bluetooth disconnect error: $e');
        }
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _connectedDevice = null;
    await _storage.delete(key: _storageKeyConnected);
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
    String? storeAddress,
    String? storePhone,
    String? thankYouNote,
    String? returnPolicy,
    String? customerName,
    String? customerPhone,
    int width = 32,
  }) {
    final StringBuffer sb = StringBuffer();

    String center(String text, {int? customWidth}) {
      final w = customWidth ?? width;
      if (text.length >= w) return text.substring(0, w);
      final pad = (w - text.length) ~/ 2;
      return ' ' * pad + text;
    }

    String twoColumn(String left, String right, {int? customWidth}) {
      final w = customWidth ?? width;
      final totalLen = left.length + right.length;
      if (totalLen >= w) {
        final maxLeft = w - right.length - 1;
        final truncatedLeft = left.length > maxLeft ? left.substring(0, maxLeft) : left;
        final spaces = w - truncatedLeft.length - right.length;
        return truncatedLeft + (' ' * (spaces > 0 ? spaces : 1)) + right;
      }
      final spaces = w - totalLen;
      return left + (' ' * spaces) + right;
    }

    final divider = '-' * width;

    sb.writeln(center(storeName.toUpperCase()));
    if (storeAddress != null && storeAddress.isNotEmpty) {
      sb.writeln(center(storeAddress));
    }
    if (storePhone != null && storePhone.isNotEmpty) {
      sb.writeln(center('Tel: $storePhone'));
    }
    sb.writeln(center('POS RECEIPT'));
    sb.writeln(divider);
    sb.writeln(twoColumn('Receipt #:', receiptNumber));
    sb.writeln(twoColumn('Date:', '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}'));
    sb.writeln(twoColumn('Cashier:', cashierName));
    if (customerName != null && customerName.isNotEmpty && customerName != 'Walk-in Customer') {
      sb.writeln(twoColumn('Customer:', customerName));
      if (customerPhone != null && customerPhone.isNotEmpty && customerPhone != '0770000000') {
        sb.writeln(twoColumn('Phone:', customerPhone));
      }
    }
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
    if (thankYouNote != null && thankYouNote.isNotEmpty) {
      sb.writeln(center(thankYouNote));
    } else {
      sb.writeln(center('THANK YOU FOR YOUR PURCHASE!'));
    }
    if (returnPolicy != null && returnPolicy.isNotEmpty) {
      sb.writeln(center(returnPolicy));
    }
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
    String? storeAddress,
    String? storePhone,
    String? thankYouNote,
    String? returnPolicy,
    String? customerName,
    String? customerPhone,
    int width = 32,
  }) async {
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
      storeAddress: storeAddress,
      storePhone: storePhone,
      thankYouNote: thankYouNote,
      returnPolicy: returnPolicy,
      customerName: customerName,
      customerPhone: customerPhone,
      width: width,
    );

    if (kDebugMode) {
      debugPrint('=== BLUETOOTH ESC/POS RECEIPT DATA ===');
      debugPrint(text);
    }

    // Physical Hardware Printing on Android / iOS
    if (!kIsWeb) {
      try {
        final bool isConn = await PrintBluetoothThermal.connectionStatus;
        if (isConn) {
          final profile = await CapabilityProfile.load();
          final paper = width >= 48 ? PaperSize.mm80 : PaperSize.mm58;
          final generator = Generator(paper, profile);
          List<int> bytes = [];

          bytes += generator.reset();
          bytes += generator.text(
            storeName,
            styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
          );
          if (storeAddress != null && storeAddress.isNotEmpty) {
            bytes += generator.text(storeAddress, styles: const PosStyles(align: PosAlign.center));
          }
          if (storePhone != null && storePhone.isNotEmpty) {
            bytes += generator.text('Tel: $storePhone', styles: const PosStyles(align: PosAlign.center));
          }
          bytes += generator.text('POS RECEIPT', styles: const PosStyles(align: PosAlign.center, bold: true));
          bytes += generator.hr();
          bytes += generator.row([
            PosColumn(text: 'Receipt #:', width: 4),
            PosColumn(text: receiptNumber, width: 8, styles: const PosStyles(align: PosAlign.right)),
          ]);
          bytes += generator.row([
            PosColumn(text: 'Date:', width: 4),
            PosColumn(
              text: '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}',
              width: 8,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
          bytes += generator.row([
            PosColumn(text: 'Cashier:', width: 4),
            PosColumn(text: cashierName, width: 8, styles: const PosStyles(align: PosAlign.right)),
          ]);
          bytes += generator.hr();

          for (final item in orderItems) {
            final name = (item['name'] ?? 'Item').toString();
            final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
            final price = double.tryParse((item['price'] ?? item['unit_price'] ?? 0.0).toString()) ?? 0.0;
            final total = double.tryParse((item['total_price'] ?? (price * qty)).toString()) ?? (price * qty);

            bytes += generator.text(name, styles: const PosStyles(bold: true));
            bytes += generator.row([
              PosColumn(text: '  $qty x ${price.toStringAsFixed(2)}', width: 7),
              PosColumn(text: total.toStringAsFixed(2), width: 5, styles: const PosStyles(align: PosAlign.right)),
            ]);
          }

          bytes += generator.hr();
          bytes += generator.row([
            PosColumn(text: 'TOTAL:', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
            PosColumn(text: 'LKR ${grandTotal.toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2)),
          ]);
          bytes += generator.row([
            PosColumn(text: 'Paid via:', width: 6),
            PosColumn(text: paymentMethod, width: 6, styles: const PosStyles(align: PosAlign.right)),
          ]);
          if (paymentMethod == 'Cash' && cashTendered > 0) {
            bytes += generator.row([
              PosColumn(text: 'Cash Tendered:', width: 6),
              PosColumn(text: 'LKR ${cashTendered.toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
            ]);
            bytes += generator.row([
              PosColumn(text: 'Change Due:', width: 6),
              PosColumn(text: 'LKR ${changeDue.toStringAsFixed(2)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
            ]);
          }
          bytes += generator.hr();
          bytes += generator.text(thankYouNote ?? 'THANK YOU FOR YOUR PURCHASE!', styles: const PosStyles(align: PosAlign.center));
          bytes += generator.feed(2);
          bytes += generator.cut();

          final sent = await PrintBluetoothThermal.writeBytes(bytes);
          if (kDebugMode) debugPrint('PrintBluetoothThermal physical writeBytes success: $sent');
          return sent;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Hardware Bluetooth print error: $e');
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 600));
    return true;
  }
}
