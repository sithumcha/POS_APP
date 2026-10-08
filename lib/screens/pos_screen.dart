import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_detail_sheet.dart';
import '../widgets/cart_checkout_sheet.dart';
import '../widgets/barcode_scanner_modal.dart';
import '../widgets/product_image_widget.dart';
import '../widgets/low_stock_restock_sheet.dart';
import '../database/app_database.dart';
import '../repositories/catalog_sync_repository.dart';
import 'product_list_screen.dart';
import 'category_setup_screen.dart';
import 'user_profile_screen.dart';
import 'login_screen.dart';

class PosScreen extends StatefulWidget {
  final String userEmail;
  final String storeName;

  const PosScreen({
    super.key,
    required this.userEmail,
    required this.storeName,
  });

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final ApiService _apiService = ApiService();
  final AppDatabase _db = AppDatabase();
  late final CatalogSyncRepository _catalogRepo = CatalogSyncRepository(apiService: _apiService, db: _db);
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _categories = [];
  List<dynamic> _subcategories = [];
  List<dynamic> _products = [];

  int? _selectedCategoryId;
  int? _selectedSubcategoryId;
  String _searchQuery = '';
  bool _isLoadingProducts = false;

  final List<Map<String, dynamic>> _cartItems = [];

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

  Future<void> _loadInitialData() async {
    setState(() => _isLoadingProducts = true);
    try {
      final categoriesData = await _catalogRepo.getCachedOrRemoteCategories();
      final productsData = await _catalogRepo.getCachedOrRemoteProducts();

      if (!mounted) return;
      setState(() {
        _categories = categoriesData;
        _products = productsData;
        _subcategories = []; // Clear mixed subcategories on initial All Items view
        _isLoadingProducts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _onCategorySelected(int? categoryId) async {
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedSubcategoryId = null;
      _subcategories = [];
      _isLoadingProducts = true;
    });

    try {
      if (categoryId != null) {
        final subcats = await _apiService.getSubcategories(categoryId: categoryId);
        if (mounted) setState(() => _subcategories = subcats);
      }
      final prods = await _apiService.getProducts(categoryId: categoryId);
      if (!mounted) return;
      setState(() {
        _products = prods;
        _isLoadingProducts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _onSubcategorySelected(int? subcategoryId) async {
    setState(() {
      _selectedSubcategoryId = subcategoryId;
      _isLoadingProducts = true;
    });

    try {
      final prods = await _apiService.getProducts(
        categoryId: _selectedCategoryId,
        subCategoryId: subcategoryId,
      );
      if (!mounted) return;
      setState(() {
        _products = prods;
        _isLoadingProducts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  double _getCleanPrice(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  void _addToCart(dynamic rawProduct) {
    if (rawProduct == null) return;
    final Map<String, dynamic> product = Map<String, dynamic>.from(rawProduct as Map);
    final String name = (product['name'] ?? 'Item').toString();

    final double discount = _getCleanPrice(product['discount_price']);
    final double regular = _getCleanPrice(product['price'] ?? product['base_price']);
    final double finalPrice = (discount > 0 && discount < regular) ? discount : (regular > 0 ? regular : 1.0);

    setState(() {
      final index = _cartItems.indexWhere((item) => item['name'] == name);
      if (index >= 0) {
        int currentQty = (_cartItems[index]['quantity'] as num).toInt();
        int newQty = currentQty + 1;
        _cartItems[index]['quantity'] = newQty;
        _cartItems[index]['total_price'] = newQty * finalPrice;
      } else {
        _cartItems.add({
          'product_id': product['id'],
          'name': name,
          'price': finalPrice,
          'unit_price': finalPrice,
          'quantity': 1,
          'total_price': finalPrice,
          'sku': (product['sku'] ?? 'N/A').toString(),
        });
      }
    });
  }

  int get _cartCount {
    int count = 0;
    for (var i in _cartItems) {
      count += (i['quantity'] as num).toInt();
    }
    return count;
  }

  double get _cartTotal {
    double sum = 0.0;
    for (var i in _cartItems) {
      sum += (i['total_price'] as num).toDouble();
    }
    return sum;
  }

  void _openProductDetailSheet(dynamic rawProduct) {
    final Map<String, dynamic> product = Map<String, dynamic>.from(rawProduct as Map);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductDetailSheet(
        productSummary: product,
        onAddToCart: (cartItem) {
          setState(() {
            final double uPrice = _getCleanPrice(cartItem['unit_price'] ?? cartItem['price']);
            final int qty = (cartItem['quantity'] is num) ? (cartItem['quantity'] as num).toInt() : 1;
            final double tPrice = cartItem.containsKey('total_price') && cartItem['total_price'] != null
                ? _getCleanPrice(cartItem['total_price'])
                : (uPrice * (qty <= 0 ? 1 : qty));

            _cartItems.add({
              ...Map<String, dynamic>.from(cartItem as Map),
              'price': uPrice,
              'unit_price': uPrice,
              'quantity': qty <= 0 ? 1 : qty,
              'total_price': tPrice,
            });
          });
        },
      ),
    );
  }

  void _openCheckoutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CartCheckoutSheet(
        cartItems: _cartItems,
        onUpdateCart: (updatedCart) {
          setState(() {
            _cartItems.clear();
            _cartItems.addAll(updatedCart);
          });
        },
        onOrderCompleted: () {
          setState(() {
            _cartItems.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order Completed Successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _openBarcodeScannerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BarcodeScannerModal(
        products: _products,
        onProductScanned: (product) => _addToCart(product),
      ),
    );
  }

  void _openLowStockRestockSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LowStockRestockSheet(
        products: _products,
        onStockUpdated: (productId, newStock) {
          setState(() {
            final idx = _products.indexWhere((p) => p['id'] == productId);
            if (idx >= 0) {
              _products[idx]['stock'] = newStock;
            }
          });
        },
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Are you sure you want to log out of your store account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _apiService.clearToken();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out successfully.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final filteredProducts = _products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final sku = (p['sku'] ?? '').toString().toLowerCase();
      return query.isEmpty || name.contains(query) || sku.contains(query);
    }).toList();

    final int lowStockCount = _products.where((p) {
      final stock = (p['stock'] is num) ? (p['stock'] as num).toInt() : 0;
      return stock <= 5;
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      bottomNavigationBar: _cartItems.isEmpty
          ? const SizedBox.shrink()
          : Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                              child: Text(
                                '$_cartCount ${_cartCount == 1 ? 'Item' : 'Items'} selected',
                                key: ValueKey<int>(_cartCount),
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                              child: Text(
                                'LKR ${_cartTotal.toStringAsFixed(2)}',
                                key: ValueKey<double>(_cartTotal),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _openCheckoutSheet,
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Checkout',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.black),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search products or SKU...',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel_rounded, color: Color(0xFF94A3B8), size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        fillColor: const Color(0xFFF1F5F9),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.black, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildIconBtn(Icons.person_outline_rounded, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(
                          userEmail: widget.userEmail,
                          storeName: widget.storeName,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 6),
                  _buildIconBtn(Icons.qr_code_scanner_rounded, _openBarcodeScannerModal),
                  const SizedBox(width: 6),
                  Stack(
                    children: [
                      _buildIconBtn(Icons.warning_amber_rounded, _openLowStockRestockSheet),
                      if (lowStockCount > 0)
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$lowStockCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  _buildIconBtn(Icons.inventory_outlined, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen()));
                  }),
                  const SizedBox(width: 6),
                  _buildIconBtn(Icons.category_outlined, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CategorySetupScreen()));
                  }),
                  const SizedBox(width: 6),
                  _buildIconBtn(Icons.logout_rounded, _handleLogout),
                ],
              ),
            ),

            // Category Chips
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(left: 16, right: 32),
                children: [
                  _buildChip('All Items', _selectedCategoryId == null, () => _onCategorySelected(null)),
                  ..._categories.map((cat) {
                    final int? id = cat['id'] as int?;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: _buildChip(
                        cat['name'] ?? '',
                        _selectedCategoryId == id,
                        () => _onCategorySelected(id),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Subcategory Chips
            if (_subcategories.isNotEmpty) ...[
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(left: 16, right: 32),
                  children: [
                    _buildSubChip(
                      'All Subcategories',
                      _selectedSubcategoryId == null,
                      () => _onSubcategorySelected(null),
                    ),
                    ..._subcategories.map((subcat) {
                      final int? id = subcat['id'] as int?;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: _buildSubChip(
                          subcat['name'] ?? '',
                          _selectedSubcategoryId == id,
                          () => _onSubcategorySelected(id),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Products Grid
            Expanded(
              child: _isLoadingProducts
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : filteredProducts.isEmpty
                      ? const Center(child: Text('No products available'))
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final item = filteredProducts[index];
                            final double regular = _getCleanPrice(item['price'] ?? item['base_price']);
                            final double discount = _getCleanPrice(item['discount_price']);
                            final bool hasDiscount = discount > 0 && discount < regular;
                            final bool isFeatured = item['featured'] == true;
                            final int stock = (item['stock'] is num) ? (item['stock'] as num).toInt() : 0;
                            final int discountPct = (hasDiscount && regular > 0)
                                ? (((regular - discount) / regular) * 100).round()
                                : 0;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Image & Badges
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _openProductDetailSheet(item),
                                      child: Stack(
                                        children: [
                                          ProductImageWidget(
                                            imageUrl: item['main_image'] ?? (item['images'] is List && (item['images'] as List).isNotEmpty ? item['images'][0] : null),
                                            productName: item['name'],
                                            width: double.infinity,
                                            height: double.infinity,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                          ),
                                          // Featured Badge Overlay (Top Left)
                                          if (isFeatured)
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFFFF5252), Color(0xFFFF7A00)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.orange.withOpacity(0.4),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('🔥 ', style: TextStyle(fontSize: 10)),
                                                    Text(
                                                      'Featured',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                          // Discount Badge Overlay (Top Right)
                                          if (hasDiscount && discountPct > 0)
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFDC2626),
                                                  borderRadius: BorderRadius.circular(12),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.red.withOpacity(0.3),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  '-$discountPct%',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                            ),

                                          // Stock Indicator Overlay (Bottom Left)
                                          Positioned(
                                            bottom: 8,
                                            left: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: stock <= 0
                                                    ? const Color(0xFFEF4444).withOpacity(0.9)
                                                    : stock <= 5
                                                        ? const Color(0xFFF59E0B).withOpacity(0.9)
                                                        : Colors.black.withOpacity(0.75),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Text('📦 ', style: TextStyle(fontSize: 9)),
                                                  Text(
                                                    stock <= 0 ? 'Out of Stock' : 'Stock: $stock',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Details Section
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () => _openProductDetailSheet(item),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'] ?? '',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'SKU: ${item['sku'] ?? 'N/A'}',
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (hasDiscount)
                                                  Text(
                                                    'LKR ${regular.toStringAsFixed(0)}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF94A3B8),
                                                      decoration: TextDecoration.lineThrough,
                                                    ),
                                                  ),
                                                Text(
                                                  'LKR ${(hasDiscount ? discount : regular).toStringAsFixed(0)}',
                                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black),
                                                ),
                                              ],
                                            ),
                                            Material(
                                              color: Colors.black,
                                              borderRadius: BorderRadius.circular(10),
                                              child: InkWell(
                                                onTap: () => _addToCart(item),
                                                borderRadius: BorderRadius.circular(10),
                                                child: const SizedBox(
                                                  width: 34,
                                                  height: 34,
                                                  child: Icon(Icons.add_rounded, color: Colors.white, size: 20),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.black, size: 22),
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSubChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE5E7EB) : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.black : const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}