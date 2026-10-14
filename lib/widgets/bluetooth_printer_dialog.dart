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
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    await _printerService.loadSavedDevices();
    if (!mounted) return;
    setState(() {
      _devices = List.from(_printerService.availableDevices);
    });
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
    });

    final scanned = await _printerService.scanDevices();

    if (!mounted) return;
    setState(() {
      _devices = List.from(scanned);
      _isScanning = false;
    });
  }

  void _showAddPrinterDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    String selectedType = 'Bluetooth 4.0 / Classic';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.bluetooth_searching, color: Colors.black),
                  SizedBox(width: 8),
                  Text('Add Bluetooth Printer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Printer Name',
                        hintText: 'e.g. Counter Printer / Thermal 58',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: addressController,
                      decoration: const InputDecoration(
                        labelText: 'Bluetooth MAC / Address',
                        hintText: 'e.g. 00:11:22:33:44:55',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Device Type',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Bluetooth 4.0 / Classic', child: Text('Bluetooth 4.0 / Classic')),
                        DropdownMenuItem(value: 'Bluetooth BLE', child: Text('Bluetooth BLE')),
                        DropdownMenuItem(value: 'ESC/POS Thermal', child: Text('ESC/POS Thermal')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedType = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final address = addressController.text.trim();
                    if (name.isEmpty || address.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter printer name and address')),
                      );
                      return;
                    }
                    final nav = Navigator.of(dialogContext);
                    final messenger = ScaffoldMessenger.of(context);
                    final newDevice = {
                      'name': name,
                      'address': address,
                      'type': selectedType,
                    };
                    await _printerService.saveDevice(newDevice);
                    nav.pop();
                    if (!mounted) return;
                    setState(() {
                      _devices = List.from(_printerService.availableDevices);
                    });
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Printer "$name" saved successfully!'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Save Printer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removePrinter(Map<String, String> device) async {
    final name = device['name'] ?? 'Printer';
    await _printerService.removeDevice(device['address'] ?? '');
    if (!mounted) return;
    setState(() {
      _devices = List.from(_printerService.availableDevices);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "$name"'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

            // Scanned Devices Section Title & Scan / Add Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Available Devices',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _showAddPrinterDialog,
                      icon: const Icon(Icons.add_rounded, size: 16, color: Colors.black),
                      label: const Text(
                        'Add',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
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
              ],
            ),
            const SizedBox(height: 6),

            // Devices List
            Flexible(
              child: _devices.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.print_disabled_rounded, size: 40, color: AppColors.textMuted),
                            const SizedBox(height: 10),
                            const Text(
                              'No Bluetooth printers found.',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Turn on your printer and pair it in phone settings, or add it manually.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.black),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: _showAddPrinterDialog,
                              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.black),
                              label: const Text(
                                'Add Printer Manually',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                            ),
                          ],
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                                tooltip: 'Remove printer',
                                onPressed: () => _removePrinter(device),
                              ),
                              const SizedBox(width: 4),
                              isConnectingThis
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isSelected ? AppColors.error : Colors.black,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        minimumSize: const Size(0, 36),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => _toggleConnect(device),
                                      child: Text(
                                        isSelected ? 'Disconnect' : 'Connect',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                            ],
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
