import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/receipt_screen.dart';

class CartCheckoutSheet extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  final Function(List<Map<String, dynamic>> updatedCart) onUpdateCart;
  final VoidCallback onOrderCompleted;

  const CartCheckoutSheet({
    super.key,
    required this.cartItems,
    required this.onUpdateCart,
    required this.onOrderCompleted,
  });

  @override
  State<CartCheckoutSheet> createState() => _CartCheckoutSheetState();
}

class _CartCheckoutSheetState extends State<CartCheckoutSheet> {
  // Selected Payment Method: 0 = Cash, 1 = Card, 2 = QR Code
  int _selectedPaymentMethod = 0;

  // Selected Discount Percentage: 0%, 5%, 10%, 15%
  double _discountPercentage = 0.0;

  // Cash Tendered string input
  String _cashTenderedInput = '';

  late List<Map<String, dynamic>> _localCart;

  @override
  void initState() {
    super.initState();
    _localCart = List<Map<String, dynamic>>.from(widget.cartItems.map((i) => Map<String, dynamic>.from(i)));
  }

  double get _subtotal {
    double total = 0.0;
    for (var item in _localCart) {
      final double unitPrice = ((item['unit_price'] ?? item['price'] ?? 0.0) as num).toDouble();
      final int qty = (item['quantity'] as num? ?? 1).toInt();
      total += (unitPrice * qty);
    }
    return total;
  }

  double get _discountAmount {
    return _subtotal * (_discountPercentage / 100.0);
  }

  double get _grandTotal {
    final net = _subtotal - _discountAmount;
    return net < 0 ? 0.0 : net;
  }

  double get _cashTendered {
    return double.tryParse(_cashTenderedInput) ?? 0.0;
  }

  double get _changeDue {
    return _cashTendered - _grandTotal;
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final currentQty = (_localCart[index]['quantity'] as num).toInt();
      final newQty = currentQty + delta;
      if (newQty <= 0) {
        _localCart.removeAt(index);
      } else {
        _localCart[index]['quantity'] = newQty;
        final double unitPrice = ((_localCart[index]['unit_price'] ?? _localCart[index]['price'] ?? 0.0) as num).toDouble();
        _localCart[index]['total_price'] = unitPrice * newQty;
      }
    });
    widget.onUpdateCart(_localCart);
  }

  void _removeItem(int index) {
    setState(() {
      _localCart.removeAt(index);
    });
    widget.onUpdateCart(_localCart);
  }

  void _handleNumPadInput(String val) {
    setState(() {
      if (val == 'C') {
        _cashTenderedInput = '';
      } else if (val == '⌫') {
        if (_cashTenderedInput.isNotEmpty) {
          _cashTenderedInput = _cashTenderedInput.substring(0, _cashTenderedInput.length - 1);
        }
      } else {
        if (_cashTenderedInput.length < 9) {
          _cashTenderedInput += val;
        }
      }
    });
  }

  void _handleCompleteOrder() {
    if (_localCart.isEmpty) return;

    if (_selectedPaymentMethod == 0 && _cashTendered < _grandTotal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient cash tendered. Please enter a valid amount.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show Printable Receipt Modal Confirmation
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildReceiptDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle indicator
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 8),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Cart Review & Checkout',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_localCart.length} items',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.black),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Body
          Expanded(
            child: _localCart.isEmpty
                ? const Center(
                    child: Text(
                      'Cart is empty',
                      style: TextStyle(fontSize: 15, color: AppColors.textMuted),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- 1. ITEMIZED LIST ---
                        const Text(
                          'Selected Products',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        const SizedBox(height: 10),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _localCart.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _localCart[index];
                            final name = item['name'] ?? 'Product';
                            final int qty = (item['quantity'] as num? ?? 1).toInt();
                            final double unitPrice = ((item['unit_price'] ?? item['price'] ?? 0.0) as num).toDouble();
                            final double itemTotal = unitPrice * qty;

                            final dynamic vars = item['variations'];
                            String variationsSummary = '';
                            if (vars is Map && vars.isNotEmpty) {
                              variationsSummary = vars.entries.map((e) {
                                final val = e.value is List ? (e.value as List).join(', ') : e.value;
                                return '${e.key}: $val';
                              }).join(' • ');
                            }

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        if (variationsSummary.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            variationsSummary,
                                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Text(
                                          'LKR ${unitPrice.toStringAsFixed(2)} each',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Quantity Stepper
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => _updateQuantity(index, -1),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Icon(Icons.remove, size: 16),
                                          ),
                                        ),
                                        Text(
                                          '$qty',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                        ),
                                        InkWell(
                                          onTap: () => _updateQuantity(index, 1),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: Icon(Icons.add, size: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Item Total Price
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'LKR ${itemTotal.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () => _removeItem(index),
                                        child: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),

                        // --- 2. BILLING SUMMARY ---
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  Text('LKR ${_subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Discount Selector Chips
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Discount', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                  Row(
                                    children: [0.0, 5.0, 10.0, 15.0].map((pct) {
                                      final isSelected = _discountPercentage == pct;
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              _discountPercentage = pct;
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.black : Colors.white,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: isSelected ? Colors.black : const Color(0xFFCBD5E1)),
                                            ),
                                            child: Text(
                                              '${pct.toInt()}%',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? Colors.white : Colors.black,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),

                              if (_discountAmount > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Discount Amount', style: TextStyle(fontSize: 12, color: AppColors.error)),
                                    Text('- LKR ${_discountAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error)),
                                  ],
                                ),
                              ],

                              const Divider(height: 20, color: Color(0xFFCBD5E1)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Net Grand Total',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black),
                                  ),
                                  Text(
                                    'LKR ${_grandTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- 3. PAYMENT SELECTOR (CASH, CARD, QR) ---
                        const Text(
                          'Select Payment Method',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildPaymentTab(0, 'Cash', Icons.payments_outlined),
                            const SizedBox(width: 8),
                            _buildPaymentTab(1, 'Card', Icons.credit_card_outlined),
                            const SizedBox(width: 8),
                            _buildPaymentTab(2, 'QR Code', Icons.qr_code_2_rounded),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // --- 4. CASH NUMPAD SECTION ---
                        if (_selectedPaymentMethod == 0) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cash Tendered & Change Calculator',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                                ),
                                const SizedBox(height: 10),

                                // Cash Tendered Display Field
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Cash Tendered:', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                                      Text(
                                        _cashTenderedInput.isEmpty ? 'LKR 0.00' : 'LKR $_cashTenderedInput.00',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Quick Amount Presets
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildPresetChip('Exact Cash (LKR ${_grandTotal.toStringAsFixed(0)})', _grandTotal.toStringAsFixed(0), isPrimary: true),
                                    _buildPresetChip('+ LKR 500', '500'),
                                    _buildPresetChip('+ LKR 1,000', '1000'),
                                    _buildPresetChip('+ LKR 2,000', '2000'),
                                    _buildPresetChip('+ LKR 5,000', '5000'),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Numeric Keypad Modal
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          _buildNumKey('1'),
                                          _buildNumKey('2'),
                                          _buildNumKey('3'),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _buildNumKey('4'),
                                          _buildNumKey('5'),
                                          _buildNumKey('6'),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _buildNumKey('7'),
                                          _buildNumKey('8'),
                                          _buildNumKey('9'),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _buildNumKey('C', isAction: true),
                                          _buildNumKey('0'),
                                          _buildNumKey('⌫', isAction: true),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Live Change Balance Display Card
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _changeDue >= 0
                                          ? [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)]
                                          : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _changeDue >= 0 ? const Color(0xFF34D399) : const Color(0xFFFDBA74),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_changeDue >= 0 ? Colors.green : Colors.orange).withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _changeDue >= 0 ? Icons.check_circle_rounded : Icons.pending_rounded,
                                            size: 22,
                                            color: _changeDue >= 0 ? const Color(0xFF047857) : const Color(0xFFC2410C),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            _changeDue >= 0 ? 'Change Balance Due:' : 'Remaining Cash Needed:',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: _changeDue >= 0 ? const Color(0xFF065F46) : const Color(0xFF9A3412),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'LKR ${_changeDue.abs().toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: _changeDue >= 0 ? const Color(0xFF047857) : const Color(0xFFC2410C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_selectedPaymentMethod == 1) ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.credit_card_rounded, size: 48, color: Colors.black),
                                SizedBox(height: 10),
                                Text(
                                  'Tap or Insert Card on POS Terminal',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Supports Visa, Mastercard, AMEX & LankaPay',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.qr_code_2_rounded, size: 64, color: Colors.black),
                                SizedBox(height: 10),
                                Text(
                                  'Scan QR Code with Bank App',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'LANKAQR & Static Merchant QR Enabled',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),

          // Action Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton.icon(
                onPressed: _localCart.isEmpty ? null : _handleCompleteOrder,
                icon: const Icon(Icons.print_outlined, color: Colors.white),
                label: Text(
                  'Complete Order & Print Bill • LKR ${_grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTab(int index, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPaymentMethod = index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.black),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String value, {bool isPrimary = false}) {
    return InkWell(
      onTap: () {
        setState(() {
          _cashTenderedInput = value;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isPrimary ? Colors.black : const Color(0xFFCBD5E1)),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isPrimary ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildNumKey(String text, {bool isAction = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () => _handleNumPadInput(text),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: isAction ? const Color(0xFFE2E8F0) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isAction ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isAction ? (text == 'C' ? const Color(0xFFDC2626) : const Color(0xFF0F172A)) : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptDialog() {
    final String paymentMethodName = _selectedPaymentMethod == 0
        ? 'Cash'
        : _selectedPaymentMethod == 1
            ? 'Credit/Debit Card'
            : 'QR Payment';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Order Placed Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
            ),
            const SizedBox(height: 6),
            const Text(
              'Receipt #INV-2026-0091 Printed',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),

            // Receipt Breakdown Box
            Container(
              padding: const EdgeInsets.all(16),
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
                      const Text('Total Paid:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text('LKR ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Mode:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text(paymentMethodName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (_selectedPaymentMethod == 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Change Returned:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        Text('LKR ${_changeDue.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // close checkout sheet

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReceiptScreen(
                      storeName: 'POS Store',
                      cashierName: 'Cashier User',
                      orderItems: _localCart,
                      subtotal: _subtotal,
                      discountAmount: _discountAmount,
                      grandTotal: _grandTotal,
                      paymentMethod: paymentMethodName,
                      cashTendered: _cashTendered,
                      changeDue: _changeDue >= 0 ? _changeDue : 0.0,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.print_rounded, color: Colors.white),
              label: const Text('View & Print Full Digital Receipt', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
