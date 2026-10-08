import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/bluetooth_printer_service.dart';
import '../widgets/bluetooth_printer_dialog.dart';
import 'pos_screen.dart';

class ReceiptScreen extends StatefulWidget {
  final String storeName;
  final String cashierName;
  final List<Map<String, dynamic>> orderItems;
  final double subtotal;
  final double discountAmount;
  final double grandTotal;
  final String paymentMethod;
  final double cashTendered;
  final double changeDue;
  final String? receiptNumber;
  final DateTime? dateTime;

  const ReceiptScreen({
    super.key,
    required this.storeName,
    required this.cashierName,
    required this.orderItems,
    required this.subtotal,
    required this.discountAmount,
    required this.grandTotal,
    required this.paymentMethod,
    this.cashTendered = 0.0,
    this.changeDue = 0.0,
    this.receiptNumber,
    this.dateTime,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  bool _isPrinting = false;
  late final String _invNum;
  late final DateTime _txTime;

  @override
  void initState() {
    super.initState();
    _invNum = widget.receiptNumber ?? 'INV-2026-${(1000 + DateTime.now().millisecond % 9000)}';
    _txTime = widget.dateTime ?? DateTime.now();
  }

  void _openBluetoothSettings() {
    showDialog(
      context: context,
      builder: (context) => const BluetoothPrinterDialog(),
    );
  }

  void _handleBluetoothPrint() async {
    if (!_printerService.isConnected) {
      // Prompt user to connect Bluetooth Printer first
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Bluetooth printer connected. Select your printer.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _openBluetoothSettings();
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    final success = await _printerService.printReceiptData(
      storeName: widget.storeName,
      cashierName: widget.cashierName,
      receiptNumber: _invNum,
      dateTime: _txTime,
      orderItems: widget.orderItems,
      subtotal: widget.subtotal,
      discountAmount: widget.discountAmount,
      grandTotal: widget.grandTotal,
      paymentMethod: widget.paymentMethod,
      cashTendered: widget.cashTendered,
      changeDue: widget.changeDue,
    );

    if (!mounted) return;
    setState(() {
      _isPrinting = false;
    });

    if (success) {
      final printerName = _printerService.connectedDevice?['name'] ?? 'Bluetooth Thermal Printer';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.print_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text('Receipt printed via $printerName!')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share Digital Receipt',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDCFCE7),
                  child: Icon(Icons.chat_rounded, color: Color(0xFF166534)),
                ),
                title: const Text('Send via WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Share PDF receipt link directly to customer'),
                onTap: () {
                  Navigator.pop(context);
                  _showShareToast('WhatsApp');
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0F2FE),
                  child: Icon(Icons.sms_rounded, color: Color(0xFF075985)),
                ),
                title: const Text('Send via SMS Text', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Send instant SMS receipt to mobile number'),
                onTap: () {
                  Navigator.pop(context);
                  _showShareToast('SMS');
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF1F5F9),
                  child: Icon(Icons.email_outlined, color: Colors.black),
                ),
                title: const Text('Email e-Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Send formatted HTML receipt to customer email'),
                onTap: () {
                  Navigator.pop(context);
                  _showShareToast('Email');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showShareToast(String channel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Receipt shared successfully via $channel!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToNewSale() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => PosScreen(
          userEmail: 'cashier@pos.com',
          storeName: widget.storeName,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate =
        '${_txTime.year}-${_txTime.month.toString().padLeft(2, '0')}-${_txTime.day.toString().padLeft(2, '0')} ${_txTime.hour.toString().padLeft(2, '0')}:${_txTime.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Digital Receipt & Print',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _printerService.isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_searching_rounded,
              color: _printerService.isConnected ? AppColors.success : Colors.black,
            ),
            onPressed: _openBluetoothSettings,
            tooltip: 'Bluetooth Printer Settings',
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.black),
            onPressed: _navigateToNewSale,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // --- 1. THERMAL PRINTABLE RECEIPT CONTAINER ---
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ClipPath(
                  clipper: ReceiptPaperClipper(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        // Store Logo & Header
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 30),
                        ),
                        const SizedBox(height: 10),

                        Text(
                          widget.storeName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '123 Main Street, Colombo 03, Sri Lanka\nTel: +94 11 234 5678',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
                        ),
                        const SizedBox(height: 16),

                        _buildDottedDivider(),
                        const SizedBox(height: 12),

                        // Receipt Metadata Row
                        _buildMetaRow('Receipt No:', _invNum),
                        const SizedBox(height: 4),
                        _buildMetaRow('Date & Time:', formattedDate),
                        const SizedBox(height: 4),
                        _buildMetaRow('Cashier:', widget.cashierName),
                        const SizedBox(height: 12),

                        _buildDottedDivider(),
                        const SizedBox(height: 14),

                        // Itemized Table Header
                        const Row(
                          children: [
                            Expanded(flex: 5, child: Text('ITEM', style: _receiptHeaderStyle)),
                            Expanded(flex: 2, child: Text('QTY x PRICE', textAlign: TextAlign.center, style: _receiptHeaderStyle)),
                            Expanded(flex: 3, child: Text('TOTAL', textAlign: TextAlign.right, style: _receiptHeaderStyle)),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Itemized Products Rows
                        ...widget.orderItems.map((item) {
                          final String name = item['name'] ?? 'Item';
                          final int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                          final double unitPrice = double.tryParse((item['unit_price'] ?? item['price'] ?? 0.0).toString()) ?? 0.0;
                          final double total = item.containsKey('total_price') && item['total_price'] != null
                              ? (double.tryParse(item['total_price'].toString()) ?? (unitPrice * qty))
                              : (unitPrice * qty);

                          final dynamic vars = item['variations'];
                          String varText = '';
                          if (vars is Map && vars.isNotEmpty) {
                            varText = vars.values.map((v) => v is List ? v.join(', ') : v.toString()).join(', ');
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        '$qty x ${unitPrice.toStringAsFixed(2)}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        total.toStringAsFixed(2),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                    ),
                                  ],
                                ),
                                if (varText.isNotEmpty)
                                  Text(
                                    '  • $varText',
                                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                  ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 14),

                        _buildDottedDivider(),
                        const SizedBox(height: 12),

                        // Billing Summary Section
                        _buildSummaryRow('Subtotal:', 'LKR ${widget.subtotal.toStringAsFixed(2)}'),
                        if (widget.discountAmount > 0) ...[
                          const SizedBox(height: 4),
                          _buildSummaryRow('Discount:', '- LKR ${widget.discountAmount.toStringAsFixed(2)}', isRed: true),
                        ],
                        const SizedBox(height: 4),
                        _buildSummaryRow('Tax (0%):', 'LKR 0.00'),
                        const SizedBox(height: 10),

                        // Grand Total Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'GRAND TOTAL:',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                            Text(
                              'LKR ${widget.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _buildDottedDivider(),
                        const SizedBox(height: 12),

                        // Payment Info
                        _buildMetaRow('Payment Mode:', widget.paymentMethod),
                        if (widget.paymentMethod == 'Cash') ...[
                          const SizedBox(height: 4),
                          _buildMetaRow('Cash Tendered:', 'LKR ${widget.cashTendered.toStringAsFixed(2)}'),
                          const SizedBox(height: 4),
                          _buildMetaRow('Change Returned:', 'LKR ${widget.changeDue.toStringAsFixed(2)}', isHighlight: true),
                        ],
                        const SizedBox(height: 16),

                        _buildDottedDivider(),
                        const SizedBox(height: 16),

                        // Footer Note & Barcode Representation
                        const Text(
                          'Thank you for shopping with us!\n*** Please come again ***',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        BarcodeWidget(code: _invNum),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- 2. ACTION BUTTONS ---
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  // Print via Bluetooth Printer Button
                  ElevatedButton.icon(
                    onPressed: _isPrinting ? null : _handleBluetoothPrint,
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.print_rounded, color: Colors.white),
                    label: Text(
                      _isPrinting ? 'Connecting to Bluetooth Printer...' : 'Print via Bluetooth Printer',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Share Receipt (WhatsApp / SMS) Button
                  OutlinedButton.icon(
                    onPressed: _showShareOptions,
                    icon: const Icon(Icons.share_rounded, color: Colors.black),
                    label: const Text(
                      'Share Receipt (WhatsApp / SMS)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: Colors.black, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // New Sale Button (Return to POS Register)
                  TextButton.icon(
                    onPressed: _navigateToNewSale,
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                    label: const Text(
                      'New Sale (Return to POS)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDottedDivider() {
    return Row(
      children: List.generate(
        32,
        (index) => Expanded(
          child: Container(
            color: index % 2 == 0 ? const Color(0xFFCBD5E1) : Colors.transparent,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String val, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(
          val,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isHighlight ? const Color(0xFF059669) : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String val, {bool isRed = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: isRed ? AppColors.error : AppColors.textSecondary)),
        Text(
          val,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isRed ? AppColors.error : Colors.black,
          ),
        ),
      ],
    );
  }
}

const TextStyle _receiptHeaderStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w900,
  letterSpacing: 0.5,
  color: Colors.black,
);

class ReceiptPaperClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const double teethWidth = 8.0;
    const double teethHeight = 5.0;

    path.moveTo(0, teethHeight);

    // Top jagged teeth
    double x = 0;
    bool up = true;
    while (x < size.width) {
      x += teethWidth;
      path.lineTo(x > size.width ? size.width : x, up ? 0 : teethHeight);
      up = !up;
    }

    path.lineTo(size.width, size.height - teethHeight);

    // Bottom jagged teeth
    x = size.width;
    up = true;
    while (x > 0) {
      x -= teethWidth;
      path.lineTo(x < 0 ? 0 : x, up ? size.height : size.height - teethHeight);
      up = !up;
    }

    path.lineTo(0, teethHeight);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class BarcodeWidget extends StatelessWidget {
  final String code;
  final double height;

  const BarcodeWidget({
    super.key,
    required this.code,
    this.height = 42,
  });

  @override
  Widget build(BuildContext context) {
    final barWidths = [3, 1, 2, 4, 1, 3, 1, 2, 4, 2, 1, 3, 1, 4, 2, 1, 3, 1, 2, 4, 1, 3, 2, 1];
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(barWidths.length, (index) {
              final isBlack = index % 2 == 0;
              return Container(
                width: barWidths[index] * 1.6,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                color: isBlack ? Colors.black : Colors.transparent,
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          code,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.5,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
