import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/currency_text.dart';
import '../widgets/product_image_widget.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/ui_animation_helper.dart';
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
  bool _isStaff = false;

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

  /// 1. PRODUCT FETCHING LOGIC:
  /// Retrieves product inventory from the backend API.
  /// Supports forceRefresh parameter to bypass in-memory caching and fetch fresh stock counts.
  Future<void> _loadProducts({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _apiService.getProducts(forceRefresh: forceRefresh),
        _apiService.isStaffUser(),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<dynamic>;
        _isStaff = results[1] as bool;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 2. PRODUCT DELETION LOGIC:
  /// Displays a safety confirmation dialog before sending the delete request to the backend.
  /// Removes the deleted item locally from the list on success for instant UI feedback.
  Future<void> _deleteProduct(int productId, String productName) async {
    if (_isStaff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Restricted: Only Admin / Store Owner can delete products.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
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

  /// 3. CREATE / EDIT PRODUCT NAVIGATION:
  /// Navigates to ProductFormScreen. If a product was saved or modified,
  /// re-fetches the latest catalog upon returning to this screen.
  Future<void> _openProductFormScreen({Map<String, dynamic>? initialProduct}) async {
    if (_isStaff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Restricted: Only Admin / Store Owner can add or modify products.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await AppNavigator.push<bool>(
      context,
      ProductFormScreen(initialProduct: initialProduct),
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

      final stock = int.tryParse(item['stock']?.toString() ?? '10') ?? 10;
      bool matchesStock = true;
      if (_selectedStockFilter == 'Low Stock') {
        matchesStock = stock <= 5;
      } else if (_selectedStockFilter == 'In Stock') {
        matchesStock = stock > 5;
      }

      return matchesQuery && matchesStock;
    }).toList();
  }

  // KPI Calculations
  int get _totalCount => _products.length;
  int get _lowStockCount => _products.where((p) => (int.tryParse(p['stock']?.toString() ?? '10') ?? 10) <= 5).length;
  double get _totalInventoryValue => _products.fold<double>(0.0, (sum, p) {
        final stock = int.tryParse(p['stock']?.toString() ?? '0') ?? 0;
        final base = double.tryParse((p['base_price'] ?? p['price'] ?? 0.0).toString()) ?? 0.0;
        final discount = p['discount_price'] != null ? double.tryParse(p['discount_price'].toString()) : null;
        final effectivePrice = (discount != null && discount > 0 && (base == 0.0 || discount < base)) ? discount : base;
        return sum + (stock * effectivePrice);
      });

  Widget _buildKpiCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required Widget valueWidget,
    required String subtitle,
  }) {
    return HoverScaleCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      borderRadius: BorderRadius.circular(16),
      scaleFactor: 1.03,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(7),
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
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: valueWidget,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              'Inventory & Catalog',
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            if (_isStaff) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text(
                  'Staff View',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: () => _loadProducts(forceRefresh: true),
          ),
        ],
      ),
      body: ResponsiveCenter(
        maxWidth: 1000,
        child: Column(
        children: [
          // --- 1. METRIC OVERVIEW CARDS (Item 5) ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              height: 106,
              child: Row(
                children: [
                  Expanded(
                    flex: 10,
                    child: _buildKpiCard(
                      icon: Icons.inventory_2_rounded,
                      iconColor: AppColors.accent,
                      iconBg: AppColors.accentLight,
                      title: 'Total Items',
                      valueWidget: Text(
                        '$_totalCount',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: 'In catalog',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 10,
                    child: _buildKpiCard(
                      icon: Icons.warning_amber_rounded,
                      iconColor: _lowStockCount > 0 ? const Color(0xFFEF4444) : AppColors.emerald,
                      iconBg: _lowStockCount > 0 ? const Color(0xFFFEF2F2) : AppColors.emeraldLight,
                      title: 'Low Stock',
                      valueWidget: Text(
                        '$_lowStockCount',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _lowStockCount > 0 ? const Color(0xFFEF4444) : AppColors.textPrimary,
                        ),
                      ),
                      subtitle: _lowStockCount > 0 ? 'Needs reorder' : 'Healthy',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 14,
                    child: _buildKpiCard(
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: AppColors.emerald,
                      iconBg: AppColors.emeraldLight,
                      title: 'Catalog Value',
                      valueWidget: CurrencyText(
                        amount: _totalInventoryValue,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      subtitle: 'Retail worth',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- 2. SEARCH BAR & FILTERS HEADER ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            color: Colors.white,
            child: Column(
              children: [
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
                const SizedBox(height: 10),

                // Stock Filter Chips Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Low Stock', 'In Stock'].map((filter) {
                      final isSelected = _selectedStockFilter == filter;
                      int count = _products.length;
                      if (filter == 'Low Stock') count = _lowStockCount;
                      if (filter == 'In Stock') count = _products.length - _lowStockCount;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(filter),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white.withOpacity(0.25) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedStockFilter = filter;
                            });
                          },
                          selectedColor: AppColors.primary,
                          backgroundColor: const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // --- 3. PRODUCT LIST TILES (Shimmer Loading Skeletons - Item 3) ---
          Expanded(
            child: _isLoading
                ? ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, __) => const ProductListSkeleton(),
                  )
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No products found',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchQuery.isNotEmpty ? 'Try a different search term' : 'Add products to your catalog',
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textMuted),
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
                          final int id = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
                          final String name = item['name']?.toString() ?? 'Product Name';
                          final String sku = item['sku']?.toString() ?? 'SKU-000';
                          final double basePrice = double.tryParse((item['base_price'] ?? item['price'] ?? 0.0).toString()) ?? 0.0;
                          final double? discountPrice = item['discount_price'] != null
                              ? double.tryParse(item['discount_price'].toString())
                              : null;
                          final int stock = int.tryParse(item['stock']?.toString() ?? '10') ?? 10;
                          final bool isLowStock = stock <= 5;

                          return FadeSlideEntrance(
                            delay: Duration(milliseconds: 30 * (index % 10)),
                            child: HoverScaleCard(
                              padding: const EdgeInsets.all(12),
                              borderRadius: BorderRadius.circular(16),
                              scaleFactor: 1.018,
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
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'SKU: $sku',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            // Price Display with Tabular Figures CurrencyText (Item 2)
                                            if (discountPrice != null) ...[
                                              CurrencyText(
                                                amount: discountPrice,
                                                fontSize: 14,
                                                color: AppColors.textPrimary,
                                              ),
                                              CurrencyText(
                                                amount: basePrice,
                                                fontSize: 11,
                                                color: AppColors.textMuted,
                                                decoration: TextDecoration.lineThrough,
                                              ),
                                            ] else
                                              CurrencyText(
                                                amount: basePrice,
                                                fontSize: 14,
                                                color: AppColors.textPrimary,
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
                                                  fontWeight: FontWeight.w700,
                                                  color: isLowStock ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Action Buttons (Edit & Delete) - Only for Admin / Owner
                                  if (!_isStaff)
                                    Row(
                                      children: [
                                        AnimatedTapButton(
                                          scaleDown: 0.88,
                                          onTap: () => _openProductFormScreen(initialProduct: item),
                                          child: const Padding(
                                            padding: EdgeInsets.all(6.0),
                                            child: Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                                          ),
                                        ),
                                        AnimatedTapButton(
                                          scaleDown: 0.88,
                                          onTap: () => _deleteProduct(id, name),
                                          child: const Padding(
                                            padding: EdgeInsets.all(6.0),
                                            child: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    ),

      // --- 4. FLOATING ACTION BUTTON (FAB +) - Only for Admin / Owner ---
      floatingActionButton: _isStaff
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openProductFormScreen(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Add Product',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
    );
  }
}
