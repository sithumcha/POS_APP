import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image_widget.dart';
import '../database/app_database.dart';

class LowStockRestockSheet extends StatefulWidget {
  final List<dynamic> products;
  final Function(int productId, int newStock) onStockUpdated;

  const LowStockRestockSheet({
    super.key,
    required this.products,
    required this.onStockUpdated,
  });

  @override
  State<LowStockRestockSheet> createState() => _LowStockRestockSheetState();
}

class _LowStockRestockSheetState extends State<LowStockRestockSheet> {
  final AppDatabase _db = AppDatabase();
  int _selectedFilterIndex = 0; // 0: All Low Stock (<=5), 1: Out of stock (==0), 2: Low Stock (1-5)
  late List<Map<String, dynamic>> _lowStockItems;

  @override
  void initState() {
    super.initState();
    _loadLowStockItems();
  }

  void _loadLowStockItems() {
    _lowStockItems = widget.products.where((p) {
      final stock = (p['stock'] is num) ? (p['stock'] as num).toInt() : 0;
      return stock <= 5;
    }).map((p) => Map<String, dynamic>.from(p as Map)).toList();
  }

  void _updateItemStock(int index, int addedQty) {
    final item = _lowStockItems[index];
    final int currentStock = (item['stock'] is num) ? (item['stock'] as num).toInt() : 0;
    final int newStock = currentStock + addedQty;

    setState(() {
      _lowStockItems[index]['stock'] = newStock;
    });

    final int id = item['id'] as int;
    widget.onStockUpdated(id, newStock);
    _db.updateProductStock(id, newStock);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restocked ${item['name']}! New stock: $newStock'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _bulkRestockAll(int addQty) {
    for (var i = 0; i < _lowStockItems.length; i++) {
      final item = _lowStockItems[i];
      final int currentStock = (item['stock'] is num) ? (item['stock'] as num).toInt() : 0;
      final int newStock = currentStock + addQty;
      _lowStockItems[i]['stock'] = newStock;

      final int id = item['id'] as int;
      widget.onStockUpdated(id, newStock);
      _db.updateProductStock(id, newStock);
    }

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bulk restocked ${_lowStockItems.length} items with +$addQty units!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _lowStockItems.where((item) {
      final stock = (item['stock'] is num) ? (item['stock'] as num).toInt() : 0;
      if (_selectedFilterIndex == 1) return stock <= 0;
      if (_selectedFilterIndex == 2) return stock > 0 && stock <= 5;
      return true;
    }).toList();

    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Low Stock & Restock Alert',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black),
                        ),
                        Text(
                          '${_lowStockItems.length} items require urgent replenishment',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.black),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Chips & Bulk Action Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 6,
                        children: [
                          _buildFilterChip('All Low (${_lowStockItems.length})', 0),
                          _buildFilterChip('Out of Stock', 1),
                          _buildFilterChip('Low (1-5)', 2),
                        ],
                      ),
                      if (_lowStockItems.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _bulkRestockAll(20),
                          icon: const Icon(Icons.flash_on_rounded, size: 16, color: Color(0xFF2563EB)),
                          label: const Text(
                            'Restock All +20',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Low Stock List
                  filteredItems.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(30),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF10B981)),
                              SizedBox(height: 10),
                              Text(
                                'All inventory levels are healthy!',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'No products currently below low stock threshold.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final int stock = (item['stock'] is num) ? (item['stock'] as num).toInt() : 0;
                            final String name = item['name'] ?? 'Product';
                            final String sku = item['sku'] ?? 'N/A';

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: stock <= 0 ? const Color(0xFFFCA5A5) : const Color(0xFFFED7AA),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Product Thumbnail
                                  ProductImageWidget(
                                    imageUrl: item['main_image'] ?? (item['images'] is List && (item['images'] as List).isNotEmpty ? item['images'][0] : null),
                                    productName: name,
                                    width: 56,
                                    height: 56,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  const SizedBox(width: 12),

                                  // Details & Stock Badge
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                                        ),
                                        const SizedBox(height: 2),
                                        Text('SKU: $sku', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                        const SizedBox(height: 6),

                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: stock <= 0 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            stock <= 0 ? 'Out of Stock (0)' : 'Low Stock ($stock remaining)',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Quick Add Stock Buttons
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Quick Add', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          _buildAddQtyBtn(index, 5, '+5'),
                                          const SizedBox(width: 4),
                                          _buildAddQtyBtn(index, 10, '+10'),
                                          const SizedBox(width: 4),
                                          _buildAddQtyBtn(index, 50, '+50'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilterIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilterIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildAddQtyBtn(int itemIndex, int qty, String label) {
    return InkWell(
      onTap: () => _updateItemStock(itemIndex, qty),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
    );
  }
}
