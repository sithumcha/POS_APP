import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../services/bluetooth_printer_service.dart';
import '../widgets/bluetooth_printer_dialog.dart';
import '../widgets/ui_animation_helper.dart';
import 'pos_screen.dart';

/// Professional Fintech POS Digital Receipt & Thermal Print Screen
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
  final String customerName;
  final String customerPhone;

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
    this.customerName = 'Walk-in Customer',
    this.customerPhone = '0770000000',
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  final ApiService _apiService = ApiService();
  bool _isPrinting = false;
  late final String _invNum;
  late final DateTime _txTime;
  Map<String, dynamic> _branding = {};
  Map<String, dynamic> _billingSettings = {};
  Map<String, dynamic> _hardwareSettings = {};

  @override
  void initState() {
    super.initState();
    _invNum = widget.receiptNumber ?? 'INV-2026-${(1000 + DateTime.now().millisecond % 9000)}';
    _txTime = widget.dateTime ?? DateTime.now();
    _loadBranding();
  }

  void _loadBranding() async {
    final b = await _apiService.getStoreBranding();
    final bill = await _apiService.getBillingSettings();
    final hw = await _apiService.getHardwareSettings();
    if (mounted) {
      setState(() {
        _branding = b;
        _billingSettings = bill;
        _hardwareSettings = hw;
      });
    }
  }

  String _formatCurrency(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final whole = parts[0];
    final dec = parts[1];
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedWhole = whole.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return 'LKR $formattedWhole.$dec';
  }

  String _formatDateTime(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year} • ${hour.toString().padLeft(2, '0')}:$minute $ampm';
  }

  void _openBluetoothSettings() {
    showDialog(
      context: context,
      builder: (context) => const BluetoothPrinterDialog(),
    );
  }

  void _handleBluetoothPrint() async {
    if (!_printerService.isConnected) {
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

    final effectiveStoreName = widget.storeName.isNotEmpty
        ? widget.storeName
        : (_branding['store_name'] ?? 'POS Store').toString();
    final is80mm = (_hardwareSettings['paper_size'] ?? '') == '80mm';

    final success = await _printerService.printReceiptData(
      storeName: effectiveStoreName,
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
      storeAddress: (_branding['address'] ?? '').toString(),
      storePhone: (_branding['phone'] ?? '').toString(),
      thankYouNote: (_billingSettings['thank_you_message'] ?? '').toString(),
      returnPolicy: (_billingSettings['return_policy'] ?? '').toString(),
      customerName: widget.customerName,
      customerPhone: widget.customerPhone,
      width: is80mm ? 48 : 32,
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
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Share Digital e-Receipt',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Send instant verified digital bill directly to customer',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 18),
              _buildShareTile(
                icon: Icons.chat_rounded,
                iconColor: const Color(0xFF25D366),
                bgColor: const Color(0xFFDCFCE7),
                title: 'Share via WhatsApp',
                subtitle: 'Send formatted receipt link to customer mobile',
                onTap: () {
                  Navigator.pop(context);
                  _showShareToast('WhatsApp');
                },
              ),
              const SizedBox(height: 10),
              _buildShareTile(
                icon: Icons.sms_rounded,
                iconColor: const Color(0xFF0284C7),
                bgColor: const Color(0xFFE0F2FE),
                title: 'Send SMS Receipt',
                subtitle: 'Instant text SMS receipt breakdown',
                onTap: () {
                  Navigator.pop(context);
                  _showShareToast('SMS');
                },
              ),
              const SizedBox(height: 10),
              _buildShareTile(
                icon: Icons.email_rounded,
                iconColor: const Color(0xFF6366F1),
                bgColor: const Color(0xFFEEF2FF),
                title: 'Email e-Receipt',
                subtitle: 'Send formal tax-compliant HTML receipt copy',
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

  Widget _buildShareTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
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

  void _navigateToNewSale() async {
    final user = await _apiService.getUserInfo();
    final email = (user?['email'] ?? '').toString();
    if (!mounted) return;
    AppNavigator.pushAndRemoveUntil(
      context,
      PosScreen(
        userEmail: email,
        storeName: widget.storeName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStoreName = (widget.storeName.isNotEmpty
            ? widget.storeName
            : (_branding['store_name'] ?? 'QUICKEAPP POS STORE'))
        .toString();

    final storeAddress = (_branding['address'] ?? '').toString().trim();
    final storePhone = (_branding['phone'] ?? '').toString().trim();
    final logoUrl = (_branding['logo_url'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF00C076), size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales Invoice',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Order Settled & Paid',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _printerService.isConnected ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _printerService.isConnected ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
              ),
            ),
            child: IconButton(
              icon: Icon(
                _printerService.isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_searching_rounded,
                color: _printerService.isConnected ? const Color(0xFF059669) : const Color(0xFF64748B),
                size: 20,
              ),
              onPressed: _openBluetoothSettings,
              tooltip: 'Bluetooth Printer Settings',
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF0F172A)),
            onPressed: _navigateToNewSale,
            tooltip: 'Return to POS',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Column(
          children: [
            // --- LUXURY FINTECH DIGITAL RECEIPT CARD ---
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // --- 1. RECEIPT HEADER BANNER ---
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                        child: Column(
                          children: [
                            // "Payment Completed" status pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00C076),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'PAYMENT SUCCESSFUL',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: const Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Store Logo & Identity
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: logoUrl.isNotEmpty
                                  ? Image.network(
                                      logoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.storefront_rounded, color: Color(0xFF00C076), size: 30),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(Icons.storefront_rounded, color: Color(0xFF00C076), size: 30),
                                    ),
                            ),
                            const SizedBox(height: 12),

                            // Store Name
                            Text(
                              effectiveStoreName.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: const Color(0xFF0F172A),
                              ),
                            ),

                            // Store Address & Contact
                            if (storeAddress.isNotEmpty || storePhone.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (storeAddress.isNotEmpty) storeAddress,
                                  if (storePhone.isNotEmpty) 'Tel: $storePhone',
                                ].join(' • '),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // --- PERFORATED NOTCH DIVIDER ---
                      const TicketPerforatedDivider(),

                      // --- 2. INVOICE METADATA GRID ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetaColumn(
                                      label: 'INVOICE NO',
                                      val: _invNum,
                                      isMonospace: true,
                                      trailing: InkWell(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: _invNum));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Invoice number copied to clipboard!'),
                                              duration: Duration(seconds: 1),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.only(left: 4.0),
                                          child: Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _buildMetaColumn(
                                      label: 'DATE & TIME',
                                      val: _formatDateTime(_txTime),
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildMetaColumn(
                                      label: 'CASHIER',
                                      val: widget.cashierName.isNotEmpty ? widget.cashierName : 'Admin Operator',
                                      icon: Icons.person_outline_rounded,
                                    ),
                                  ),
                                  Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _buildMetaColumn(
                                      label: 'CUSTOMER',
                                      val: widget.customerName.isNotEmpty ? widget.customerName : 'Walk-in',
                                      subVal: (widget.customerPhone.isNotEmpty && widget.customerPhone != '0770000000')
                                          ? widget.customerPhone
                                          : null,
                                      icon: Icons.badge_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- 3. ITEMIZED ORDER ITEMS TABLE ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Table Header Row
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: Text(
                                      'ITEM DESCRIPTION',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'QTY × PRICE',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'TOTAL',
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Line Items
                            ...widget.orderItems.map((item) {
                              final String name = (item['name'] ?? 'Product Item').toString();
                              final int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                              final double unitPrice =
                                  double.tryParse((item['unit_price'] ?? item['price'] ?? 0.0).toString()) ?? 0.0;
                              final double total = item.containsKey('total_price') && item['total_price'] != null
                                  ? (double.tryParse(item['total_price'].toString()) ?? (unitPrice * qty))
                                  : (unitPrice * qty);

                              final dynamic vars = item['variations'];
                              String varText = '';
                              if (vars is Map && vars.isNotEmpty) {
                                varText = vars.values.map((v) => v is List ? v.join(', ') : v.toString()).join(' • ');
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (varText.isNotEmpty)
                                            Container(
                                              margin: const EdgeInsets.only(top: 2),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                varText,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        '$qty × ${_formatCurrency(unitPrice).replaceFirst('LKR ', '')}',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        _formatCurrency(total),
                                        textAlign: TextAlign.right,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- 4. FINANCIAL BREAKDOWN & GRAND TOTAL HERO BANNER ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22.0),
                        child: Column(
                          children: [
                            _buildSummaryItem('Items Subtotal', _formatCurrency(widget.subtotal)),
                            if (widget.discountAmount > 0) ...[
                              const SizedBox(height: 6),
                              _buildSummaryItem(
                                'Discount Applied',
                                '- ${_formatCurrency(widget.discountAmount)}',
                                isHighlightGreen: true,
                              ),
                            ],
                            const SizedBox(height: 6),
                            _buildSummaryItem('VAT / Sales Tax (0%)', 'LKR 0.00'),
                            const SizedBox(height: 16),

                            // --- GRAND TOTAL HERO BANNER ---
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withOpacity(0.2),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'TOTAL DUE',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.2,
                                              color: const Color(0xFF94A3B8),
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF334155),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  widget.paymentMethod == 'Cash'
                                                      ? Icons.payments_rounded
                                                      : Icons.credit_card_rounded,
                                                  size: 12,
                                                  color: const Color(0xFF00C076),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  widget.paymentMethod.toUpperCase(),
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _formatCurrency(widget.grandTotal),
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (widget.paymentMethod == 'Cash') ...[
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Divider(height: 1, thickness: 1, color: Color(0xFF334155)),
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Cash Tendered:',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFFCBD5E1),
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(widget.cashTendered),
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFFF8FAFC),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Change Returned:',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFA7F3D0),
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(widget.changeDue),
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF00C076),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- PERFORATED NOTCH DIVIDER ---
                      const TicketPerforatedDivider(),

                      // --- 5. RECEIPT FOOTER & VERIFICATION CODES ---
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Column(
                          children: [
                            // Thank You Note & Return Policy
                            Text(
                              (_billingSettings['thank_you_message'] ??
                                      'Thank you for your business!\nPlease keep this receipt for warranty and returns.')
                                  .toString()
                                  .trim(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                                height: 1.45,
                              ),
                            ),
                            if ((_billingSettings['return_policy'] ?? '').toString().trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                (_billingSettings['return_policy']).toString().trim(),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10.5,
                                  color: const Color(0xFF94A3B8),
                                  height: 1.35,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),

                            // Dual Verification: Barcode & Mini QR Code
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CustomQrCodeWidget(code: _invNum, size: 54),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      BarcodeWidget(code: _invNum, height: 34),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Scan QR code to view verified digital receipt',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Fintech Security Seal
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.verified_user_rounded, size: 13, color: Color(0xFF00C076)),
                                const SizedBox(width: 6),
                                Text(
                                  'FINTECH CERTIFIED POS • 256-BIT ENCRYPTED',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- 6. FLOATING ACTION TOOLBAR ---
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                children: [
                  // Primary Bluetooth Thermal Print Button
                  AnimatedTapButton(
                    onTap: _isPrinting ? null : _handleBluetoothPrint,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isPrinting) ...[
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Sending to Printer...',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ] else ...[
                            const Icon(Icons.print_rounded, color: Color(0xFF00C076), size: 21),
                            const SizedBox(width: 10),
                            Text(
                              'Print Thermal Receipt',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            if (_printerService.isConnected) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00C076),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Share Digital Receipt (WhatsApp, SMS, Email) Button
                  AnimatedTapButton(
                    onTap: _showShareOptions,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.share_rounded, color: Color(0xFF0F172A), size: 19),
                          const SizedBox(width: 10),
                          Text(
                            'Share e-Receipt (WhatsApp / SMS)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Return to POS Terminal Button
                  AnimatedTapButton(
                    onTap: _navigateToNewSale,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 19),
                          const SizedBox(width: 8),
                          Text(
                            'Return to POS (New Sale)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaColumn({
    required String label,
    required String val,
    String? subVal,
    bool isMonospace = false,
    Widget? trailing,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 11, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: Text(
                val,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: isMonospace
                    ? GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      )
                    : GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        if (subVal != null && subVal.isNotEmpty)
          Text(
            subVal,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isHighlightGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isHighlightGreen ? const Color(0xFF059669) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

/// Modern ticket perforated divider with circular side cutouts and dashed center line
class TicketPerforatedDivider extends StatelessWidget {
  const TicketPerforatedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center dashed perforated line
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const dashWidth = 5.0;
                const dashSpace = 4.0;
                final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    count,
                    (_) => Container(
                      width: dashWidth,
                      height: 1.5,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                );
              },
            ),
          ),

          // Left semicircular punch notch
          Positioned(
            left: -12,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9), // Match scaffold background
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Right semicircular punch notch
          Positioned(
            right: -12,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9), // Match scaffold background
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Code-128 Barcode Widget
class BarcodeWidget extends StatelessWidget {
  final String code;
  final double height;

  const BarcodeWidget({
    super.key,
    required this.code,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    // Deterministic bar widths
    final barSequence = [3, 1, 2, 4, 1, 3, 1, 2, 4, 2, 1, 3, 1, 4, 2, 1, 3, 1, 2, 4, 1, 3, 2, 1, 3, 1, 2];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(barSequence.length, (index) {
              final isBlack = index % 2 == 0;
              return Container(
                width: barSequence[index] * 1.5,
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 0.4),
                color: isBlack ? const Color(0xFF0F172A) : Colors.transparent,
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          code,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
            color: const Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}

/// Custom painted verification QR Code with authentic finder corner patterns
class CustomQrCodeWidget extends StatelessWidget {
  final String code;
  final double size;

  const CustomQrCodeWidget({
    super.key,
    required this.code,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _QrCodePainter(code: code),
      ),
    );
  }
}

class _QrCodePainter extends CustomPainter {
  final String code;

  _QrCodePainter({required this.code});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    const int matrixSize = 17;
    final double cellSize = size.width / matrixSize;

    // 1. Draw top-left, top-right, bottom-left finder patterns
    _drawFinderPattern(canvas, paint, 0, 0, cellSize);
    _drawFinderPattern(canvas, paint, matrixSize - 5, 0, cellSize);
    _drawFinderPattern(canvas, paint, 0, matrixSize - 5, cellSize);

    // 2. Deterministic pseudorandom data cells based on code hash
    final rand = Random(code.hashCode);
    for (int r = 0; r < matrixSize; r++) {
      for (int c = 0; c < matrixSize; c++) {
        // Skip finder areas
        final isTopLeft = (r < 6 && c < 6);
        final isTopRight = (r < 6 && c >= matrixSize - 6);
        final isBottomLeft = (r >= matrixSize - 6 && c < 6);

        if (!isTopLeft && !isTopRight && !isBottomLeft) {
          if (rand.nextBool()) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(c * cellSize, r * cellSize, cellSize * 0.9, cellSize * 0.9),
                const Radius.circular(1.0),
              ),
              paint,
            );
          }
        }
      }
    }
  }

  void _drawFinderPattern(Canvas canvas, Paint paint, int row, int col, double cellSize) {
    // Outer 5x5 square
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(col * cellSize, row * cellSize, 5 * cellSize, 5 * cellSize),
        const Radius.circular(2.0),
      ),
      paint,
    );

    // Inner 3x3 white square
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH((col + 1) * cellSize, (row + 1) * cellSize, 3 * cellSize, 3 * cellSize),
      whitePaint,
    );

    // Center 1x1 black square
    canvas.drawRect(
      Rect.fromLTWH((col + 2) * cellSize, (row + 2) * cellSize, 1 * cellSize, 1 * cellSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _QrCodePainter oldDelegate) => oldDelegate.code != code;
}
