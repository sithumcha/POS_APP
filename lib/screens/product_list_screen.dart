import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_image_widget.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _products = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedStockFilter = 'All'; // 'All', 'Low Stock', 'In Stock'

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await _apiService.getProducts();
      if (!mounted) return;
      setState(() {
        _products = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteProduct(int productId, String productName) async {
    // Confirmation Alert Box
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to delete "$productName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _apiService.deleteProduct(productId);
      if (success) {
        setState(() {
          _products.removeWhere((item) => item['id'] == productId);
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product "$productName" deleted successfully.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openProductFormScreen({Map<String, dynamic>? initialProduct}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductFormScreen(initialProduct: initialProduct),
      ),
    );
    if (result == true) {
      _loadProducts();
    }
  }

  List<dynamic> get _filteredProducts {
    return _products.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final sku = (item['sku'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      final matchesQuery = query.isEmpty || name.contains(query) || sku.contains(query);

      final stock = (item['stock'] as num? ?? 10).toInt();
      bool matchesStock = true;
      if (_selectedStockFilter == 'Low Stock') {
        matchesStock = stock < 5;
      } else if (_selectedStockFilter == 'In Stock') {
        matchesStock = stock >= 5;
      }

      return matchesQuery && matchesStock;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Inventory & Catalog',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: Column(
        children: [
          // --- 1. SEARCH BAR & FILTERS HEADER ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Live Search Bar
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products by name or SKU...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Stock Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Low Stock', 'In Stock'].map((filter) {
                      final isSelected = _selectedStockFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedStockFilter = filter;
                            });
                          },
                          selectedColor: Colors.black,
                          backgroundColor: const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // --- 2. PRODUCT LIST TILES ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text(
                              'No products found',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchQuery.isNotEmpty ? 'Try a different search term' : 'Add products to your catalog',
                              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final int id = item['id'];
                          final String name = item['name'] ?? 'Product Name';
                          final String sku = item['sku'] ?? 'SKU-000';
                          final double basePrice = ((item['base_price'] ?? item['price'] ?? 0.0) as num).toDouble();
                          final double? discountPrice = item['discount_price'] != null
                              ? ((item['discount_price']) as num).toDouble()
                              : null;
                          final int stock = (item['stock'] as num? ?? 10).toInt();
                          final bool isLowStock = stock < 5;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ProductImageWidget(
                                  imageUrl: item['main_image'] ?? (item['images'] is List && (item['images'] as List).isNotEmpty ? item['images'][0] : null),
                                  productName: name,
                                  width: 60,
                                  height: 60,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                const SizedBox(width: 14),

                                // Product Info Stack
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'SKU: $sku',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          // Price
                                          if (discountPrice != null) ...[
                                            Text(
                                              'LKR ${discountPrice.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            Text(
                                              'LKR ${basePrice.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textMuted,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ] else
                                            Text(
                                              'LKR ${basePrice.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),

                                          // Stock Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isLowStock ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isLowStock ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0),
                                              ),
                                            ),
                                            child: Text(
                                              isLowStock ? 'Low Stock ($stock)' : 'In Stock ($stock)',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isLowStock ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Action Buttons (Edit & Delete)
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.black),
                                      onPressed: () => _openProductFormScreen(initialProduct: item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                                      onPressed: () => _deleteProduct(id, name),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),

      // --- 3. FLOATING ACTION BUTTON (FAB +) ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductFormScreen(),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
