import 'package:flutter/material.dart';
import '../services/bluetooth_printer_service.dart';
import '../theme/app_theme.dart';

class BluetoothPrinterDialog extends StatefulWidget {
  const BluetoothPrinterDialog({super.key});

  @override
  State<BluetoothPrinterDialog> createState() => _BluetoothPrinterDialogState();
}

class _BluetoothPrinterDialogState extends State<BluetoothPrinterDialog> {
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _connectingDeviceAddress;

  List<Map<String, String>> _devices = [];

  @override
  void initState() {
    super.initState();
    _devices = _printerService.availableDevices;
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
    });

    final scanned = await _printerService.scanDevices();

    if (!mounted) return;
    setState(() {
      _devices = scanned;
      _isScanning = false;
    });
  }

  Future<void> _toggleConnect(Map<String, String> device) async {
    final isCurrent = _printerService.connectedDevice?['address'] == device['address'];

    if (isCurrent) {
      await _printerService.disconnectDevice();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth Printer disconnected'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _isConnecting = true;
        _connectingDeviceAddress = device['address'];
      });

      final success = await _printerService.connectDevice(device);

      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _connectingDeviceAddress = null;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device['name']}!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _testPrint() async {
    if (!_printerService.isConnected) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Printing Test Receipt via Bluetooth...'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await _printerService.printReceiptData(
      storeName: 'MY SUPERMARKET POS',
      cashierName: 'Admin Cashier',
      receiptNumber: 'TEST-0001',
      dateTime: DateTime.now(),
      orderItems: [
        {'name': 'Test Item A', 'quantity': 1, 'price': 500.0, 'total_price': 500.0},
        {'name': 'Test Item B', 'quantity': 2, 'price': 250.0, 'total_price': 500.0},
      ],
      subtotal: 1000.0,
      discountAmount: 0.0,
      grandTotal: 1000.0,
      paymentMethod: 'Cash',
      cashTendered: 1000.0,
      changeDue: 0.0,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test Receipt Printed Successfully!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectedDev = _printerService.connectedDevice;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bluetooth_audio_rounded, color: Colors.black, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Bluetooth Printer',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Pair and select your 58mm / 80mm ESC/POS thermal printer.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),

            // Connection Status Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: connectedDev != null ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: connectedDev != null ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    connectedDev != null ? Icons.check_circle_rounded : Icons.bluetooth_disabled_rounded,
                    color: connectedDev != null ? AppColors.success : AppColors.error,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connectedDev != null ? 'Connected Printer' : 'No Printer Connected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: connectedDev != null ? const Color(0xFF166534) : const Color(0xFF991B1B),
                          ),
                        ),
                        Text(
                          connectedDev != null
                              ? '${connectedDev['name']} (${connectedDev['address']})'
                              : 'Tap a printer below to connect',
                          style: TextStyle(
                            fontSize: 11,
                            color: connectedDev != null ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Scanned Devices Section Title & Scan Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Devices',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                TextButton.icon(
                  onPressed: _isScanning ? null : _startScan,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16, color: Colors.black),
                  label: Text(
                    _isScanning ? 'Scanning...' : 'Scan',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Devices List
            Flexible(
              child: _devices.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No Bluetooth printers found.\nEnsure printer is turned on & paired in phone settings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _devices.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final isSelected = connectedDev?['address'] == device['address'];
                        final isConnectingThis = _isConnecting && _connectingDeviceAddress == device['address'];

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.black : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.print_rounded,
                              color: isSelected ? Colors.white : Colors.black87,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            device['name'] ?? 'Bluetooth Printer',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${device['address']} • ${device['type']}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                          trailing: isConnectingThis
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected ? AppColors.error : Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    minimumSize: const Size(0, 36),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _toggleConnect(device),
                                  child: Text(
                                    isSelected ? 'Disconnect' : 'Connect',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),

            // Bottom Actions: Test Print & Done
            Row(
              children: [
                if (connectedDev != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.black),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _testPrint,
                      icon: const Icon(Icons.print_rounded, size: 18, color: Colors.black),
                      label: const Text(
                        'Test Print',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                  ),
                if (connectedDev != null) const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
