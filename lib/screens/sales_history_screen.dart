import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../services/api_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../widgets/bluetooth_printer_dialog.dart';
import '../widgets/ui_animation_helper.dart';
import 'receipt_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final ApiService _apiService = ApiService();
  final BluetoothPrinterService _printerService = BluetoothPrinterService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _orders = [];
  bool _isLoading = true;
  String _selectedPaymentFilter = 'All'; // All, Paid, Refunded, Cancelled
  String _selectedDateFilter = 'Today'; // Today, This Week, All Time
  String _searchQuery = '';

  // KPI stats
  double _totalRevenue = 0.0;
  int _totalBills = 0;
  double _avgBillValue = 0.0;
  int _paidBills = 0;
  int _cancelledBills = 0;

  dynamic _currentUserId = 1;
  String _currentUserName = '';
  String _currentUserEmail = '';
  bool _isAdmin = false;
  String _selectedCashierFilter = 'All Staff';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Extracts structured Cashier info from either top-level fields or encoded notes JSON
  Map<String, dynamic> _getCashierInfo(Map<String, dynamic> order) {
    // 1. Direct fields
    if (order['cashier_name'] != null && order['cashier_name'].toString().isNotEmpty) {
      return {
        'id': order['cashier_id'] ?? order['cashierId'],
        'name': order['cashier_name'].toString().trim(),
        'role': (order['role'] ?? 'staff').toString(),
        'email': (order['cashier_email'] ?? order['email'] ?? '').toString().trim(),
      };
    }

    // 2. Parsed from notes JSON metadata
    final notes = order['notes'];
    if (notes != null && notes.toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(notes.toString());
        if (decoded is Map<String, dynamic>) {
          final cName = (decoded['cashier_name'] ?? decoded['cashierName'] ?? '').toString().trim();
          if (cName.isNotEmpty) {
            return {
              'id': decoded['cashier_id'] ?? decoded['cashierId'],
              'name': cName,
              'role': (decoded['role'] ?? 'staff').toString(),
              'email': (decoded['cashier_email'] ?? decoded['email'] ?? '').toString().trim(),
            };
          }
        }
      } catch (_) {}
    }

    // 3. Fallback: Store Admin / Owner
    return {
      'id': order['user_id'] ?? 1,
      'name': 'Store Admin',
      'role': 'admin',
      'email': '',
    };
  }

  /// Available cashier names across current orders (For Admin filtering)
  List<String> get _availableCashiers {
    final names = <String>{'All Staff'};
    for (var o in _orders) {
      final map = o is Map<String, dynamic> ? o : Map<String, dynamic>.from(o as Map);
      final cashier = _getCashierInfo(map);
      final name = (cashier['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        names.add(name);
      }
    }
    return names.toList();
  }

  /// 1. INITIALIZATION & ROLE DETECTION:
  /// Identifies current user role (Owner/Admin vs Staff Member).
  /// Cashier only sees their own bills, while Owner sees all staff bills.
  Future<void> _loadInitialData() async {
    final user = await _apiService.getUserInfo();
    final isStaff = await _apiService.isStaffUser();
    _isAdmin = !isStaff;

    if (user != null) {
      if (user['id'] != null) {
        _currentUserId = user['id'];
      }
      _currentUserEmail = (user['email'] ?? '').toString().toLowerCase().trim();
      final firstName = (user['first_name'] ?? '').toString().trim();
      final lastName = (user['last_name'] ?? '').toString().trim();
      _currentUserName = '$firstName $lastName'.trim();
      if (_currentUserName.isEmpty) {
        _currentUserName = (user['name'] ?? user['email'] ?? 'Staff').toString();
      }
    }

    await Future.wait([
      _fetchOrders(),
      _fetchStats(),
    ]);
  }

  /// 2. DATE QUERY FORMATTER:
  /// Returns standard YYYY-MM-DD query string for 'Today' filter.
  String _getDateQuery() {
    final now = DateTime.now();
    if (_selectedDateFilter == 'Today') {
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }
    return '';
  }

  /// 3. KPI REVENUE STATS FETCHING:
  /// For Admin: Retrieves full store statistics from getOrderStats API.
  /// For Staff: Computes strictly based on this staff member's drawer/shift totals.
  Future<void> _fetchStats() async {
    if (!mounted) return;

    if (!_isAdmin) {
      // Staff only sees their own shift collections
      _computeStatsLocally();
      return;
    }

    final dateStr = _getDateQuery();
    final res = await _apiService.getOrderStats(date: dateStr);
    if (!mounted) return;

    if (res['success'] == true && _selectedCashierFilter == 'All Staff') {
      setState(() {
        _totalRevenue = (res['total_revenue'] as num?)?.toDouble() ?? 0.0;
        _totalBills = (res['total_bills'] as num?)?.toInt() ?? 0;
        _avgBillValue = (res['avg_bill_value'] as num?)?.toDouble() ?? 0.0;
        _paidBills = (res['paid_bills'] as num?)?.toInt() ?? 0;
        _cancelledBills = (res['cancelled_bills'] as num?)?.toInt() ?? 0;
      });
    } else {
      _computeStatsLocally();
    }
  }

  void _computeStatsLocally() {
    double rev = 0.0;
    int paid = 0;
    int cancelled = 0;

    final targetOrders = _orders.where((o) {
      final map = o is Map<String, dynamic> ? o : Map<String, dynamic>.from(o as Map);
      if (!_isAdmin) {
        final cashier = _getCashierInfo(map);
        final cashierId = cashier['id']?.toString().trim();
        final cashierName = cashier['name']?.toString().toLowerCase().trim() ?? '';
        final cashierEmail = (cashier['email'] ?? '').toString().toLowerCase().trim();

        final myId = _currentUserId?.toString().trim();
        final myName = _currentUserName.toLowerCase().trim();
        final myEmail = _currentUserEmail.toLowerCase().trim();

        final bool idMatches = (cashierId != null && myId != null && cashierId.isNotEmpty && myId.isNotEmpty && cashierId == myId);
        final bool nameMatches = (cashierName.isNotEmpty && myName.isNotEmpty &&
            (cashierName == myName || cashierName.contains(myName) || myName.contains(cashierName)));
        final bool emailMatches = (cashierEmail.isNotEmpty && myEmail.isNotEmpty && cashierEmail == myEmail);

        final bool isMyOrder = idMatches || nameMatches || emailMatches;
        return isMyOrder;
      }
      if (_isAdmin && _selectedCashierFilter != 'All Staff') {
        final cashier = _getCashierInfo(map);
        return cashier['name'] == _selectedCashierFilter;
      }
      return true;
    }).toList();

    for (var o in targetOrders) {
      final map = o is Map<String, dynamic> ? o : (o as Map);
      final status = (map['order_status'] ?? map['status'] ?? '').toString().toLowerCase();
      final paymentStatus = (map['payment_status'] ?? '').toString().toLowerCase();
      final total = double.tryParse((map['total_amount'] ?? map['totalAmount'] ?? map['total'] ?? 0.0).toString()) ?? 0.0;

      final bool isRefunded = status == 'cancelled' || status == 'refunded' || paymentStatus == 'refunded';

      if (isRefunded) {
        cancelled++;
      } else {
        paid++;
        rev += total;
      }
    }

    setState(() {
      _totalRevenue = rev;
      _totalBills = targetOrders.length;
      _paidBills = paid;
      _cancelledBills = cancelled;
      _avgBillValue = paid > 0 ? (rev / paid) : 0.0;
    });
  }

  List<dynamic> get _filteredOrders {
    return _orders.where((o) {
      final order = o is Map<String, dynamic> ? o : Map<String, dynamic>.from(o as Map);

      // 1. Role Filter: Staff ONLY sees bills processed by their own account
      if (!_isAdmin) {
        final cashier = _getCashierInfo(order);
        final cashierId = cashier['id']?.toString().trim();
        final cashierName = cashier['name']?.toString().toLowerCase().trim() ?? '';
        final cashierEmail = (cashier['email'] ?? '').toString().toLowerCase().trim();

        final myId = _currentUserId?.toString().trim();
        final myName = _currentUserName.toLowerCase().trim();
        final myEmail = _currentUserEmail.toLowerCase().trim();

        final bool idMatches = (cashierId != null && myId != null && cashierId.isNotEmpty && myId.isNotEmpty && cashierId == myId);
        final bool nameMatches = (cashierName.isNotEmpty && myName.isNotEmpty &&
            (cashierName == myName || cashierName.contains(myName) || myName.contains(cashierName)));
        final bool emailMatches = (cashierEmail.isNotEmpty && myEmail.isNotEmpty && cashierEmail == myEmail);

        final bool isMyOrder = idMatches || nameMatches || emailMatches;

        if (!isMyOrder) return false;
      }

      // 2. Admin Cashier Filter: Filter by selected cashier
      if (_isAdmin && _selectedCashierFilter != 'All Staff') {
        final cashier = _getCashierInfo(order);
        final cashierName = (cashier['name'] ?? '').toString().trim();
        if (cashierName != _selectedCashierFilter) return false;
      }

      final status = (order['order_status'] ?? order['status'] ?? '').toString().toLowerCase();
      final paymentStatus = (order['payment_status'] ?? '').toString().toLowerCase();
      final bool isRefunded = status == 'cancelled' || status == 'refunded' || paymentStatus == 'refunded';

      if (_selectedPaymentFilter == 'Refunded') {
        if (!isRefunded) return false;
      } else if (_selectedPaymentFilter == 'Paid') {
        if (isRefunded) return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final receiptNo = (order['receipt_number'] ?? order['order_number'] ?? order['id'] ?? '').toString().toLowerCase();
        final name = (order['customer_name'] ?? '').toString().toLowerCase();
        final phone = (order['customer_phone'] ?? '').toString().toLowerCase();
        final cashier = _getCashierInfo(order);
        final cashierName = (cashier['name'] ?? '').toString().toLowerCase();
        if (!receiptNo.contains(q) && !name.contains(q) && !phone.contains(q) && !cashierName.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    if (_searchQuery.trim().isNotEmpty) {
      final results = await _apiService.searchOrders(
        userId: _currentUserId,
        query: _searchQuery.trim(),
      );
      if (!mounted) return;
      setState(() {
        _orders = results;
        _isLoading = false;
      });
      return;
    }

    final dateStr = _getDateQuery();
    final res = await _apiService.getOrders(
      date: dateStr,
      paymentStatus: null,
    );

    if (!mounted) return;
    if (res['success'] == true && res['orders'] is List) {
      setState(() {
        _orders = res['orders'] as List;
        _isLoading = false;
      });
      _computeStatsLocally();
    } else {
      // Fallback empty list or sample structure for smooth first-time experience
      setState(() {
        _orders = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCancelOrRefund(Map<String, dynamic> order) async {
    final orderId = order['id'] ?? order['order_id'];
    final receiptNo = order['receipt_number'] ?? order['order_number'] ?? '#$orderId';
    final total = double.tryParse((order['total_amount'] ?? order['total'] ?? 0.0).toString()) ?? 0.0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 28),
            SizedBox(width: 8),
            Text('Cancel & Refund Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel and refund bill $receiptNo?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Refund Amount:', style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w600)),
                  Text(
                    'LKR ${total.toStringAsFixed(2)}',
                    style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'This will mark the bill as cancelled/refunded and restore stock.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Dismiss', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Confirm Refund', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing bill refund...'), duration: Duration(seconds: 1)),
      );

      final res = await _apiService.updateOrderStatus(
        orderId,
        orderStatus: 'cancelled',
        paymentStatus: 'refunded',
        reason: 'Customer Return / In-Store Void',
      );

      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bill $receiptNo marked as Cancelled & Refunded.'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
          _fetchOrders();
          _fetchStats();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? 'Refund failed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleDeleteOrder(Map<String, dynamic> order) async {
    final orderId = order['id'] ?? order['order_id'];
    final receiptNo = (order['receipt_number'] ?? order['order_number'] ?? '#$orderId').toString();
    final orderNo = (order['order_number'] ?? '').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 28),
            SizedBox(width: 8),
            Text('Delete Bill Permanently', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to permanently delete bill $receiptNo from the database?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFF991B1B), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Warning: This action cannot be undone. The transaction will be permanently erased.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deleting bill from database...'), duration: Duration(seconds: 1)),
      );

      final res = await _apiService.deleteOrder(
        orderId,
        orderNumber: orderNo,
        receiptNumber: receiptNo,
      );

      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _orders.removeWhere((o) {
            final map = o is Map<String, dynamic> ? o : Map<String, dynamic>.from(o as Map);
            final id = (map['id'] ?? map['order_id'] ?? '').toString();
            final rNo = (map['receipt_number'] ?? map['order_number'] ?? '').toString();
            final oNo = (map['order_number'] ?? '').toString();
            return id == orderId.toString() || rNo == receiptNo || (orderNo.isNotEmpty && oNo == orderNo);
          });
        });
        _computeStatsLocally();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Bill $receiptNo deleted successfully.'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        _fetchOrders();
        _fetchStats();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Delete failed'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openBillDetailsSheet(Map<String, dynamic> order) async {
    final orderId = order['id'] ?? order['order_id'];
    
    // Fetch full order details (GET /orders/{id})
    final detailsRes = await _apiService.getOrderDetails(orderId);
    final fullOrder = (detailsRes['success'] == true && detailsRes['order'] is Map<String, dynamic>)
        ? detailsRes['order'] as Map<String, dynamic>
        : order;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BillDetailsModal(
        order: fullOrder,
        isAdmin: _isAdmin,
        onReprint: () {
          Navigator.pop(ctx);
          _reprintReceipt(fullOrder);
        },
        onCancelRefund: () {
          Navigator.pop(ctx);
          _handleCancelOrRefund(fullOrder);
        },
        onDelete: () {
          Navigator.pop(ctx);
          _handleDeleteOrder(fullOrder);
        },
      ),
    );
  }

  void _reprintReceipt(Map<String, dynamic> order) {
    final itemsRaw = order['items'] ?? order['order_items'] ?? [];
    final itemsList = (itemsRaw is List)
        ? itemsRaw.map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];

    final total = double.tryParse((order['total_amount'] ?? order['total'] ?? 0.0).toString()) ?? 0.0;
    final subtotal = double.tryParse((order['subtotal'] ?? total).toString()) ?? total;
    final receiptNo = order['receipt_number'] ?? order['order_number'] ?? 'INV-${order['id']}';
    final paymentMethod = order['payment_method'] ?? 'Cash';
    final paidAmount = double.tryParse((order['paid_amount'] ?? total).toString()) ?? total;
    final changeAmount = double.tryParse((order['change_amount'] ?? 0.0).toString()) ?? 0.0;

    AppNavigator.push(
      context,
      ReceiptScreen(
        storeName: order['store_name'] ?? 'QUICKE POS Store',
        cashierName: _getCashierInfo(order)['name']?.toString() ?? 'Staff',
        orderItems: itemsList,
        subtotal: subtotal,
        discountAmount: (subtotal - total).clamp(0.0, double.infinity),
        grandTotal: total,
        paymentMethod: paymentMethod.toString().toUpperCase(),
        cashTendered: paidAmount,
        changeDue: changeAmount,
        receiptNumber: receiptNo.toString(),
        dateTime: DateTime.tryParse(order['created_at']?.toString() ?? '') ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isAdmin ? 'Sales & Bills History' : 'My Sales & Bills',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              _isAdmin
                  ? 'All Cashiers & Transactions Ledger'
                  : 'Cashier: $_currentUserName (${_filteredOrders.length} Bills)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Bluetooth Printer',
            icon: Icon(
              Icons.print_rounded,
              color: _printerService.isConnected ? const Color(0xFF059669) : AppColors.textSecondary,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const BluetoothPrinterDialog(),
              );
            },
          ),
          IconButton(
            tooltip: 'Refresh Bills',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () {
              _fetchOrders();
              _fetchStats();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_fetchOrders(), _fetchStats()]);
        },
        child: ResponsiveCenter(
          maxWidth: 1000,
          child: Column(
          children: [
            // --- TOP KPI METRICS CARDS (GET /orders/stats) ---
            _buildKpiMetricsHeader(),

            // --- SEARCH & FILTER CONTROLS (GET /orders/search) ---
            _buildSearchAndFilters(),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // --- BILLS LIST (GET /orders) ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredOrders.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredOrders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index] is Map<String, dynamic>
                                ? _filteredOrders[index] as Map<String, dynamic>
                                : Map<String, dynamic>.from(_filteredOrders[index] as Map);
                            return FadeSlideEntrance(
                              delay: Duration(milliseconds: 30 * (index % 8)),
                              child: _buildOrderCard(order),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildKpiMetricsHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SizedBox(
        height: 102,
        child: Row(
          children: [
            // 1. Revenue Card
            Expanded(
              flex: 13,
              child: _buildMetricCard(
                icon: Icons.account_balance_wallet_rounded,
                iconColor: const Color(0xFF059669),
                iconBg: const Color(0xFFECFDF5),
                cardBg: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
                title: _isAdmin ? 'Revenue' : 'My Revenue',
                value: 'LKR ${_totalRevenue.toStringAsFixed(0)}',
                subtitle: _isAdmin ? '$_paidBills Paid Bills' : '$_paidBills Billed by Me',
              ),
            ),
            const SizedBox(width: 8),

            // 2. Total Bills Card
            Expanded(
              flex: 10,
              child: _buildMetricCard(
                icon: Icons.receipt_long_rounded,
                iconColor: AppColors.accent,
                iconBg: AppColors.accentLight,
                cardBg: const Color(0xFFF5F3FF),
                borderColor: const Color(0xFFDDD6FE),
                title: _isAdmin ? 'Total Bills' : 'My Bills',
                value: '$_totalBills',
                subtitle: '$_cancelledBills Refunded',
              ),
            ),
            const SizedBox(width: 8),

            // 3. Average Bill Card
            Expanded(
              flex: 11,
              child: _buildMetricCard(
                icon: Icons.trending_up_rounded,
                iconColor: const Color(0xFF6366F1),
                iconBg: const Color(0xFFEEF2FF),
                cardBg: const Color(0xFFF8FAFC),
                borderColor: const Color(0xFFE2E8F0),
                title: _isAdmin ? 'Avg. Bill' : 'My Avg.',
                value: 'LKR ${_avgBillValue.toStringAsFixed(0)}',
                subtitle: 'Per transaction',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String value,
    required String subtitle,
    Color? cardBg,
    Color? borderColor,
  }) {
    return HoverScaleCard(
      backgroundColor: cardBg ?? Colors.white,
      border: Border.all(color: borderColor ?? const Color(0xFFE2E8F0), width: 1.2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      borderRadius: BorderRadius.circular(14),
      scaleFactor: 1.03,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // Search Input
          TextField(
            controller: _searchController,
            onSubmitted: (val) {
              setState(() => _searchQuery = val);
              _fetchOrders();
            },
            decoration: InputDecoration(
              hintText: 'Search by Receipt #, phone, or name...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _fetchOrders();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Filters row
          Row(
            children: [
              // Date filter chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDateFilter,
                    isDense: true,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    items: ['Today', 'This Week', 'All Time'].map((d) {
                      return DropdownMenuItem(value: d, child: Text(d));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedDateFilter = val);
                        _fetchOrders();
                        _fetchStats();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Payment Status Filter Chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      {'key': 'All', 'label': 'All', 'count': _orders.length},
                      {'key': 'Paid', 'label': 'Paid', 'count': _paidBills},
                      {'key': 'Refunded', 'label': 'Refunded', 'count': _cancelledBills},
                    ].map((item) {
                      final key = item['key'] as String;
                      final label = item['label'] as String;
                      final count = item['count'] as int;
                      final isSelected = _selectedPaymentFilter == key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text('$label ($count)'),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedPaymentFilter = key);
                          },
                          selectedColor: AppColors.primary,
                          backgroundColor: const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),

          // Cashier Filter Chips (For Admin when multiple cashiers exist)
          if (_isAdmin && _availableCashiers.length > 2) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 6.0),
                    child: Text('Staff:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                  ),
                  ..._availableCashiers.map((cName) {
                    final isSel = _selectedCashierFilter == cName;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(cName),
                        selected: isSel,
                        onSelected: (_) {
                          setState(() {
                            _selectedCashierFilter = cName;
                          });
                          _computeStatsLocally();
                        },
                        selectedColor: const Color(0xFF0F172A),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['id'] ?? order['order_id'];
    final receiptNo = order['receipt_number'] ?? order['order_number'] ?? 'INV-$orderId';
    final total = double.tryParse((order['total_amount'] ?? order['total'] ?? 0.0).toString()) ?? 0.0;
    final status = (order['order_status'] ?? order['status'] ?? 'completed').toString().toLowerCase();
    final paymentStatus = (order['payment_status'] ?? '').toString().toLowerCase();
    final paymentMethod = (order['payment_method'] ?? 'cash').toString().toLowerCase();
    final itemsCount = (order['items'] is List) ? (order['items'] as List).length : 1;
    final createdAt = order['created_at']?.toString() ?? 'Just now';

    final cashierInfo = _getCashierInfo(order);
    final String cashierName = cashierInfo['name']?.toString() ?? 'Store Admin';
    final String cashierRole = cashierInfo['role']?.toString().toLowerCase() ?? 'admin';
    final bool isStaffCashier = cashierRole == 'staff' || cashierRole == 'cashier';
    final customerName = (order['customer_name'] ?? order['customerName'] ?? '').toString().trim();

    final bool isCancelled = status == 'cancelled' || status == 'refunded' || paymentStatus == 'refunded';

    return HoverScaleCard(
      borderRadius: BorderRadius.circular(16),
      scaleFactor: 1.018,
      padding: EdgeInsets.zero,
      onTap: () => _openBillDetailsSheet(order),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Receipt # & Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        receiptNo.toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      createdAt.length > 16 ? createdAt.substring(0, 16) : createdAt,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCancelled ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCancelled ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Text(
                    isCancelled ? 'REFUNDED' : 'PAID',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isCancelled ? const Color(0xFFDC2626) : const Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle Row: Amount & Items
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LKR ${total.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isCancelled ? const Color(0xFF94A3B8) : AppColors.textPrimary,
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          paymentMethod.contains('card')
                              ? Icons.credit_card_rounded
                              : (paymentMethod.contains('qr') ? Icons.qr_code_2_rounded : Icons.payments_rounded),
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          paymentMethod.toUpperCase(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                        const SizedBox(width: 8),
                        Text(
                          '$itemsCount items',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),

                // Quick Action Buttons
                Row(
                  children: [
                    // Thermal Re-print button
                    AnimatedTapButton(
                      scaleDown: 0.88,
                      onTap: () => _reprintReceipt(order),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.print_rounded, size: 18, color: AppColors.textPrimary),
                      ),
                    ),
                    if (_isAdmin) ...[
                      const SizedBox(width: 6),
                      // Admin Delete Bill button
                      AnimatedTapButton(
                        scaleDown: 0.88,
                        onTap: () => _handleDeleteOrder(order),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFEE2E2)),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    // View details arrow
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Bottom Cashier & Customer Info Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                children: [
                  // Cashier badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isStaffCashier ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isStaffCashier ? const Color(0xFFBBF7D0) : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isStaffCashier ? Icons.badge_outlined : Icons.shield_outlined,
                          size: 11,
                          color: isStaffCashier ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Cashier: $cashierName',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isStaffCashier ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Customer name if present
                  if (customerName.isNotEmpty && customerName != 'Walk-in Customer') ...[
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    const SizedBox(width: 8),
                    const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            'No Bills Found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty ? 'No bills match "$_searchQuery"' : 'Placed bills from POS will appear here.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// --- BILL DETAILS & REPRINT BOTTOM SHEET (GET /orders/{id}) ---
// -------------------------------------------------------------
class _BillDetailsModal extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onReprint;
  final VoidCallback onCancelRefund;
  final bool isAdmin;
  final VoidCallback? onDelete;

  const _BillDetailsModal({
    required this.order,
    required this.onReprint,
    required this.onCancelRefund,
    this.isAdmin = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final orderId = order['id'] ?? order['order_id'];
    final receiptNo = order['receipt_number'] ?? order['order_number'] ?? 'INV-$orderId';
    final total = double.tryParse((order['total_amount'] ?? order['total'] ?? 0.0).toString()) ?? 0.0;
    final subtotal = double.tryParse((order['subtotal'] ?? total).toString()) ?? total;
    final status = (order['order_status'] ?? order['status'] ?? 'completed').toString().toLowerCase();
    final paymentStatus = (order['payment_status'] ?? '').toString().toLowerCase();
    final paymentMethod = (order['payment_method'] ?? 'cash').toString();
    final itemsRaw = order['items'] ?? order['order_items'] ?? [];
    final itemsList = (itemsRaw is List) ? itemsRaw : [];
    final bool isCancelled = status == 'cancelled' || status == 'refunded' || paymentStatus == 'refunded';

    // Cashier and Customer info
    String cashierName = (order['cashier_name'] ?? order['cashierName'] ?? '').toString().trim();
    String cashierRole = (order['role'] ?? '').toString().trim();
    if (cashierName.isEmpty && order['notes'] != null) {
      try {
        final decoded = jsonDecode(order['notes'].toString());
        if (decoded is Map<String, dynamic>) {
          cashierName = (decoded['cashier_name'] ?? decoded['cashierName'] ?? '').toString().trim();
          cashierRole = (decoded['role'] ?? '').toString().trim();
        }
      } catch (_) {}
    }
    if (cashierName.isEmpty) {
      cashierName = 'Store Admin';
      cashierRole = 'admin';
    }
    final bool isStaffCashier = cashierRole.toLowerCase() == 'staff' || cashierRole.toLowerCase() == 'cashier';
    final customerName = (order['customer_name'] ?? order['customerName'] ?? '').toString().trim();
    final customerPhone = (order['customer_phone'] ?? order['customerPhone'] ?? '').toString().trim();

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bill Details', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(receiptNo.toString(), style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCancelled ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCancelled ? 'REFUNDED' : 'PAID',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isCancelled ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        ),
                      ),
                    ),
                    if (isAdmin && onDelete != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Delete Bill Permanently (Admin Only)',
                        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 22),
                        onPressed: onDelete,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Cashier and Customer info card
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isStaffCashier ? Icons.badge_outlined : Icons.shield_outlined,
                                size: 16,
                                color: isStaffCashier ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Billed By: $cashierName',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isStaffCashier ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isStaffCashier ? 'Staff' : 'Owner / Admin',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isStaffCashier ? const Color(0xFF15803D) : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (customerName.isNotEmpty && customerName != 'Walk-in Customer') ...[
                        const Divider(height: 16, color: Color(0xFFE2E8F0)),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Text(
                              'Customer: $customerName',
                              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                            ),
                            if (customerPhone.isNotEmpty && customerPhone != '0770000000') ...[
                              const Spacer(),
                              Text(
                                customerPhone,
                                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                Text('PURCHASED ITEMS', style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
                const SizedBox(height: 10),

                if (itemsList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Itemized details logged with transaction.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  )
                else
                  ...itemsList.map((item) {
                    final map = item is Map<String, dynamic> ? item : (item as Map);
                    final name = map['name'] ?? map['product_name'] ?? 'Product';
                    final qty = map['quantity'] ?? map['qty'] ?? 1;
                    final price = double.tryParse((map['price'] ?? map['unit_price'] ?? 0.0).toString()) ?? 0.0;
                    final rowTotal = double.tryParse((map['total_price'] ?? (price * (qty as num))).toString()) ?? (price * (qty as num));

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                Text('$qty x LKR ${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          Text('LKR ${rowTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }),

                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // Payment summary
                _buildSummaryRow('Subtotal', 'LKR ${subtotal.toStringAsFixed(2)}'),
                if (subtotal > total)
                  _buildSummaryRow('Discount', '- LKR ${(subtotal - total).toStringAsFixed(2)}', isDiscount: true),
                _buildSummaryRow('Payment Method', paymentMethod.toUpperCase()),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(
                      'LKR ${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF059669)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Row(
              children: [
                if (isAdmin) ...[
                  if (!isCancelled) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCancelRefund,
                        icon: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 16),
                        label: const Text('Refund', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onDelete != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 16),
                        label: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF2F2),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onReprint,
                    icon: const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                    label: const Text('Re-Print', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildSummaryRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDiscount ? const Color(0xFF059669) : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
