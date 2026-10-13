import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/product_detail_sheet.dart';
import '../widgets/cart_checkout_sheet.dart';
import '../widgets/barcode_scanner_modal.dart';
import '../widgets/product_image_widget.dart';
import '../widgets/low_stock_restock_sheet.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/currency_text.dart';
import '../widgets/ui_animation_helper.dart';
import '../database/app_database.dart';
import '../repositories/catalog_sync_repository.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import 'product_list_screen.dart';
import 'category_setup_screen.dart';
import 'user_profile_screen.dart';
import 'sales_history_screen.dart';
import 'store_setup_screen.dart';
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
  bool _isStaff = false;

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

  /// 1. CATALOG INITIALIZATION:
  /// Loads initial categories and products using CatalogSyncRepository.
  /// Prioritizes Drift SQLite offline cache for lightning speed, then syncs with remote backend.
  Future<void> _loadInitialData() async {
    setState(() => _isLoadingProducts = true);
    try {
      final results = await Future.wait([
        _catalogRepo.getCachedOrRemoteCategories(),
        _catalogRepo.getCachedOrRemoteProducts(),
        _apiService.isStaffUser(),
      ]);

      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<dynamic>;
        _products = results[1] as List<dynamic>;
        _isStaff = results[2] as bool;
        _subcategories = []; // Clear subcategories on initial "All Items" catalog view
        _isLoadingProducts = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  /// 2. CATEGORY FILTER LOGIC:
  /// Filters catalog by category. If null is passed, displays all items.
  /// Automatically fetches cascading subcategories for the selected category.
  Future<void> _onCategorySelected(int? categoryId) async {
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedSubcategoryId = null; // Reset previously selected subcategory
      _subcategories = [];
      _isLoadingProducts = true;
    });

    try {
      if (categoryId != null) {
        // Concurrently fetch subcategories and products belonging to the selected category
        final results = await Future.wait([
          _apiService.getSubcategories(categoryId: categoryId),
          _apiService.getProducts(categoryId: categoryId),
        ]);
        if (!mounted) return;
        setState(() {
          _subcategories = results[0];
          _products = results[1];
          _isLoadingProducts = false;
        });
      } else {
        // If "All Categories" is selected, fetch all products
        final prods = await _apiService.getProducts();
        if (!mounted) return;
        setState(() {
          _products = prods;
          _isLoadingProducts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  /// Refreshes catalog by reloading current category/subcategory or full catalog
  Future<void> _refreshCatalog() async {
    if (_selectedSubcategoryId != null) {
      await _onSubcategorySelected(_selectedSubcategoryId);
    } else if (_selectedCategoryId != null) {
      await _onCategorySelected(_selectedCategoryId);
    } else {
      await _loadInitialData();
    }
  }

  /// 3. SUBCATEGORY FILTER LOGIC:
  /// Refines product catalog to only show items belonging to a specific subcategory.
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

  /// 4. PRICE CLEANING & SANITIZATION:
  /// Safely converts dynamic price values (strings, ints, or doubles) to double format.
  double _getCleanPrice(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  /// 5. ADD TO CART LOGIC:
  /// Adds a selected product to the cart. If the product already exists in the cart,
  /// increments its quantity and recalculates its total price.
  void _addToCart(dynamic rawProduct) {
    if (rawProduct == null) return;
    HapticFeedback.lightImpact(); // Subtle haptic feedback for mobile/tablet POS experience
    final Map<String, dynamic> product = Map<String, dynamic>.from(rawProduct as Map);
    final String name = (product['name'] ?? 'Item').toString();

    // Calculate effective price: Use discount price if valid & lower than regular price
    final double discount = _getCleanPrice(product['discount_price']);
    final double regular = _getCleanPrice(product['price'] ?? product['base_price']);
    final double finalPrice = (discount > 0 && discount < regular) ? discount : (regular > 0 ? regular : 1.0);

    setState(() {
      final index = _cartItems.indexWhere((item) => item['name'] == name);
      if (index >= 0) {
        // Item already in cart: increment quantity
        int currentQty = int.tryParse(_cartItems[index]['quantity']?.toString() ?? '1') ?? 1;
        int newQty = currentQty + 1;
        _cartItems[index]['quantity'] = newQty;
        _cartItems[index]['total_price'] = newQty * finalPrice;
      } else {
        // Item not in cart: insert new line item
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

  /// 6. TOTAL ITEMS IN CART:
  /// Sums the quantities of all active line items in the cart.
  int get _cartCount {
    int count = 0;
    for (var i in _cartItems) {
      count += int.tryParse(i['quantity']?.toString() ?? '1') ?? 1;
    }
    return count;
  }

  /// 7. TOTAL BILLING VALUE:
  /// Sums total prices across all active cart items.
  double get _cartTotal {
    double sum = 0.0;
    for (var i in _cartItems) {
      sum += double.tryParse(i['total_price']?.toString() ?? '0.0') ?? 0.0;
    }
    return sum;
  }

  /// 8. PRODUCT DETAIL BOTTOM SHEET:
  /// Opens product details for custom variant options or quantity adjustments.
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
            final int qty = int.tryParse(cartItem['quantity']?.toString() ?? '1') ?? 1;
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

  /// 9. CHECKOUT SHEET TRIGGER:
  /// Opens checkout sheet for customer assignment, payment method selection (Cash/Card),
  /// offline receipt queuing, and order finalization.
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
          // Clear cart upon successful payment and order creation
          setState(() {
            _cartItems.clear();
          });
          // Reload catalog so deducted product stocks are immediately refreshed on the POS screen
          _refreshCatalog();
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

  /// 10. BARCODE SCANNER MODAL:
  /// Opens camera/laser scanner modal to quickly look up items and add directly to cart.
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
      AppNavigator.pushAndRemoveUntil(
        context,
        const LoginScreen(),
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

    final bool isWideTerminal = Responsive.isWideTerminal(context);
    final int gridColumns = isWideTerminal
        ? (MediaQuery.of(context).size.width > 1200 ? 4 : 3)
        : Responsive.getGridColumns(context);
    final double cardRatio = Responsive.getProductCardAspectRatio(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      bottomNavigationBar: SafeArea(
        top: false,
        child: ResponsiveCenter(
          maxWidth: isWideTerminal ? 640 : double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isWideTerminal && _cartItems.isNotEmpty) _buildCheckoutBar(),
              _buildBottomDock(lowStockCount),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: isWideTerminal
            ? Row(
                children: [
                  Expanded(
                    child: _buildCatalogColumn(filteredProducts, lowStockCount, gridColumns, cardRatio),
                  ),
                  Container(width: 1, color: const Color(0xFFE2E8F0)),
                  SizedBox(
                    width: 380,
                    child: _buildWideCartSidebar(),
                  ),
                ],
              )
            : _buildCatalogColumn(filteredProducts, lowStockCount, gridColumns, cardRatio),
      ),
    );
  }

  Widget _buildCatalogColumn(
    List<dynamic> filteredProducts,
    int lowStockCount,
    int gridColumns,
    double cardRatio,
  ) {
    return Column(
      children: [
        // --- 1. STORE & TERMINAL IDENTITY BAR ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 21),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.storeName.isNotEmpty ? widget.storeName : 'Quicke POS Terminal',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Row(
                          children: [
                            const PulsingStatusDot(color: Color(0xFF10B981), size: 6),
                            const SizedBox(width: 6),
                            Text(
                              _isStaff ? 'Staff Cashier Mode' : 'Store Owner / Admin',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<List<AppNotificationItem>>(
                    valueListenable: NotificationService().notificationsNotifier,
                    builder: (context, notifications, _) {
                      final unreadCount = notifications.where((n) => !n.isRead).length;
                      final totalBadge = unreadCount + (lowStockCount > 0 ? 1 : 0);

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildIconBtn(Icons.notifications_outlined, _openNotificationsSheet),
                          if (totalBadge > 0)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$totalBadge',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildIconBtn(Icons.person_outline_rounded, () {
                    AppNavigator.push(
                      context,
                      UserProfileScreen(
                        userEmail: widget.userEmail,
                        storeName: widget.storeName,
                      ),
                    );
                  }),
                ],
              ),
            ),

            // --- 2. SEARCH BAR ---
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search products or SKU...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF94A3B8), fontSize: 13.5),
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
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.8),
                  ),
                ),
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

            // Products Grid (Shimmer Skeleton Loading - Item 3)
            Expanded(
              child: _isLoadingProducts
                  ? GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridColumns,
                        childAspectRatio: cardRatio,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      itemCount: 6,
                      itemBuilder: (_, __) => const ProductGridSkeleton(),
                    )
                  : filteredProducts.isEmpty
                      ? const Center(child: Text('No products available'))
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridColumns,
                            childAspectRatio: cardRatio,
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

                            return HoverScaleCard(
                              borderRadius: BorderRadius.circular(20),
                              padding: EdgeInsets.zero,
                              scaleFactor: 1.022,
                              onTap: () => _openProductDetailSheet(item),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Image & Badges
                                  Expanded(
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

                                  // Details Section
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'] ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13.5,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'SKU: ${item['sku'] ?? 'N/A'}',
                                              style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                                            ),
                                          ],
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
                                                  CurrencyText(
                                                    amount: regular,
                                                    fontSize: 11,
                                                    color: const Color(0xFF94A3B8),
                                                    decoration: TextDecoration.lineThrough,
                                                  ),
                                                CurrencyText(
                                                  amount: hasDiscount ? discount : regular,
                                                  fontSize: 14,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ],
                                            ),
                                            AnimatedTapButton(
                                              scaleDown: 0.88,
                                              onTap: () => _addToCart(item),
                                              child: Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: Colors.black,
                                                  borderRadius: BorderRadius.circular(11),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.18),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
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
        );
  }

  /// --------------------------------------------------------------------------
  /// TABLET LANDSCAPE DEDICATED CART SIDEBAR (Item 1 & 2)
  /// Live interactive order pane that keeps cart items and checkout in plain sight.
  /// --------------------------------------------------------------------------
  Widget _buildWideCartSidebar() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, size: 20, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Order',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '$_cartCount ${_cartCount == 1 ? 'item' : 'items'} in cart',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_cartItems.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear Cart',
                    icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444), size: 22),
                    onPressed: () {
                      setState(() => _cartItems.clear());
                      HapticFeedback.lightImpact();
                    },
                  ),
              ],
            ),
          ),

          // Items list or Empty state
          Expanded(
            child: _cartItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_shopping_cart_rounded, size: 40, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Cart is Empty',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap any product or scan barcode to add items to this sale',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cartItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = _cartItems[index];
                      final String name = (item['name'] ?? 'Item').toString();
                      final int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                      final double unitPrice = _getCleanPrice(item['unit_price'] ?? item['price']);
                      final double lineTotal = double.tryParse(item['total_price']?.toString() ?? '0') ?? (unitPrice * qty);

                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  CurrencyText(
                                    amount: unitPrice,
                                    fontSize: 11.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Qty buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      if (qty <= 1) {
                                        _cartItems.removeAt(index);
                                      } else {
                                        final nq = qty - 1;
                                        _cartItems[index]['quantity'] = nq;
                                        _cartItems[index]['total_price'] = nq * unitPrice;
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.remove, size: 14, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(
                                    '$qty',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      final nq = qty + 1;
                                      _cartItems[index]['quantity'] = nq;
                                      _cartItems[index]['total_price'] = nq * unitPrice;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.add, size: 14, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(width: 10),
                            SizedBox(
                              width: 65,
                              child: CurrencyText(
                                amount: lineTotal,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Sidebar Footer / Checkout Panel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: const Color(0xFF64748B)),
                    ),
                    CurrencyText(
                      amount: _cartTotal,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Due',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    CurrencyText(
                      amount: _cartTotal,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF10B981),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _cartItems.isEmpty ? null : _openCheckoutSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.credit_card_rounded, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Checkout & Pay',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap) {
    return AnimatedTapButton(
      scaleDown: 0.90,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF1E293B), size: 21),
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap) {
    return AnimatedTapButton(
      scaleDown: 0.94,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isSelected ? Colors.white : const Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSubChip(String label, bool isSelected, VoidCallback onTap) {
    return AnimatedTapButton(
      scaleDown: 0.94,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.16),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0F172A).withOpacity(0.92),
                  const Color(0xFF1E293B).withOpacity(0.88),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(scale: anim, child: child),
                          ),
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
                          child: CurrencyText(
                            key: ValueKey<double>(_cartTotal),
                            amount: _cartTotal,
                            fontSize: 18,
                            color: Colors.white,
                            currencyColor: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                AnimatedTapButton(
                  scaleDown: 0.94,
                  onTap: _openCheckoutSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Checkout',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.black),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// CREATIVE ANIMATED BOTTOM NAVIGATION DOCK:
  /// Features glassmorphic backdrop, spring bounce taps, active glowing pill,
  /// elevated primary scanner action, direct Sales History shortcut, and Quick Menu Hub.
  Widget _buildBottomDock(int lowStockCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.92),
                  Colors.white.withOpacity(0.78),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.95),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.08),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // 1. POS Terminal Tab (Active)
                _buildBottomDockItem(
                  icon: Icons.point_of_sale_rounded,
                  label: 'POS',
                  isActive: true,
                  onTap: () {
                    HapticFeedback.selectionClick();
                  },
                ),
                // 2. Sales History Shortcut
                _buildBottomDockItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Sales',
                  onTap: () {
                    AppNavigator.push(context, const SalesHistoryScreen());
                  },
                ),
                // 3. Elevated Floating Barcode Scanner
                _buildBottomDockItem(
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan',
                  isPrimary: true,
                  onTap: _openBarcodeScannerModal,
                ),
                // 4. Products Inventory
                _buildBottomDockItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Products',
                  badgeCount: lowStockCount,
                  onTap: () {
                    AppNavigator.push(context, const ProductListScreen()).then((_) => _loadInitialData());
                  },
                ),
                // 5. Quick Navigation Menu Hub
                _buildBottomDockItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Menu',
                  onTap: _openQuickNavigationSheet,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// CREATIVE DOCK ITEM WITH SPRING TAP AND ACTIVE GLOW:
  Widget _buildBottomDockItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int badgeCount = 0,
    bool isPrimary = false,
    bool isActive = false,
  }) {
    return Expanded(
      child: AnimatedTapButton(
        scaleDown: 0.88,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (isPrimary)
                    Container(
                      width: 52,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1E293B),
                            Color(0xFF0F172A),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 0,
                            left: 4,
                            right: 4,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.25),
                                    Colors.white.withOpacity(0.0),
                                  ],
                                ),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                            ),
                          ),
                          Icon(icon, color: Colors.white, size: 21),
                        ],
                      ),
                    )
                  else
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFECFDF5) : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: isActive
                            ? Border.all(color: const Color(0xFFA7F3D0), width: 1.2)
                            : null,
                      ),
                      child: Icon(
                        icon,
                        color: isActive
                            ? const Color(0xFF059669)
                            : const Color(0xFF475569),
                        size: 22,
                      ),
                    ),
                  if (badgeCount > 0)
                    Positioned(
                      right: isPrimary ? -2 : -4,
                      top: isPrimary ? -2 : -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isPrimary || isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isPrimary
                      ? const Color(0xFF0F172A)
                      : (isActive ? const Color(0xFF059669) : const Color(0xFF64748B)),
                  letterSpacing: -0.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// CREATIVE QUICK NAVIGATION HUB MODAL:
  /// Glassmorphic bottom sheet providing fast, animated access to all app features.
  void _openQuickNavigationSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ResponsiveCenter(
          maxWidth: 580,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.12),
                    blurRadius: 32,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag indicator handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Store Header banner with live server status
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.storeName.isNotEmpty ? widget.storeName : 'QuickeApp POS',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.userEmail,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Quick navigation grid
                  GridView.count(
                    crossAxisCount: _isStaff ? 2 : 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: _isStaff ? 1.22 : 0.95,
                    children: [
                      // 1. Categories - Admin / Owner Only
                      if (!_isStaff)
                        _buildQuickNavTile(
                          icon: Icons.category_rounded,
                          color: const Color(0xFF8B5CF6),
                          label: 'Categories',
                          onTap: () {
                            Navigator.pop(context);
                            AppNavigator.push(context, const CategorySetupScreen())
                                .then((_) => _loadInitialData());
                          },
                        ),

                      // 2. Sales History
                      _buildQuickNavTile(
                        icon: Icons.receipt_long_rounded,
                        color: const Color(0xFF3B82F6),
                        label: 'Sales History',
                        onTap: () {
                          Navigator.pop(context);
                          AppNavigator.push(context, const SalesHistoryScreen());
                        },
                      ),

                      // 3. Inventory / Products Catalog
                      _buildQuickNavTile(
                        icon: Icons.inventory_2_rounded,
                        color: const Color(0xFF10B981),
                        label: _isStaff ? 'View Products' : 'Inventory',
                        onTap: () {
                          Navigator.pop(context);
                          AppNavigator.push(context, const ProductListScreen())
                              .then((_) => _loadInitialData());
                        },
                      ),

                      // 4. Store Branding Setup - Admin / Owner Only
                      if (!_isStaff)
                        _buildQuickNavTile(
                          icon: Icons.store_mall_directory_rounded,
                          color: const Color(0xFFF59E0B),
                          label: 'Store Setup',
                          onTap: () {
                            Navigator.pop(context);
                            AppNavigator.push(
                              context,
                              StoreSetupScreen(
                                userEmail: widget.userEmail,
                                initialStoreName: widget.storeName,
                                isEditing: true,
                              ),
                            );
                          },
                        ),

                      // 5. Profile & Account Settings
                      _buildQuickNavTile(
                        icon: _isStaff ? Icons.person_outline_rounded : Icons.person_rounded,
                        color: const Color(0xFF06B6D4),
                        label: _isStaff ? 'My Profile' : 'Staff & Profile',
                        onTap: () {
                          Navigator.pop(context);
                          AppNavigator.push(
                            context,
                            UserProfileScreen(
                              userEmail: widget.userEmail,
                              storeName: widget.storeName,
                            ),
                          );
                        },
                      ),

                      // 6. Stock Alerts
                      _buildQuickNavTile(
                        icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFEF4444),
                        label: 'Stock Alerts',
                        onTap: () {
                          Navigator.pop(context);
                          _openLowStockRestockSheet();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Logout action button
                  AnimatedTapButton(
                    onTap: () {
                      Navigator.pop(context);
                      _handleLogout();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Sign Out from Terminal',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
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
        ),
      );
    },
    );
  }

  /// Helper rendering individual interactive tile inside the Quick Navigation Sheet:
  Widget _buildQuickNavTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return AnimatedTapButton(
      scaleDown: 0.92,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _openNotificationsSheet() {
    NotificationService().markAllAsRead();

    final int lowStock = _products.where((p) {
      final stock = (p['stock'] is num) ? (p['stock'] as num).toInt() : 0;
      return stock <= 5;
    }).length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return ResponsiveCenter(
            maxWidth: 580,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notifications_active_rounded, color: Color(0xFF0F172A), size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Notifications & Alerts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 4),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- 1. SYSTEM PERMISSIONS STATUS CARD ---
                        FutureBuilder<Map<String, bool>>(
                          future: () async {
                            final notif = await PermissionService().isNotificationGranted();
                            final bt = await PermissionService().isBluetoothGranted();
                            return {'notif': notif, 'bt': bt};
                          }(),
                          builder: (context, snapshot) {
                            final notifGranted = snapshot.data?['notif'] ?? true;
                            final btGranted = snapshot.data?['bt'] ?? true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Phone System Access & Permissions',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF475569),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Notification Permission Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            notifGranted ? Icons.check_circle_rounded : Icons.notifications_off_outlined,
                                            size: 18,
                                            color: notifGranted ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Phone Notification Bar Alerts',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                          ),
                                        ],
                                      ),
                                      if (!notifGranted)
                                        TextButton(
                                          onPressed: () async {
                                            await PermissionService().requestNotificationPermission();
                                            setSheetState(() {});
                                          },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            backgroundColor: const Color(0xFF0F172A),
                                            foregroundColor: Colors.white,
                                            minimumSize: Size.zero,
                                          ),
                                          child: const Text('Allow', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Bluetooth Permission Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            btGranted ? Icons.check_circle_rounded : Icons.bluetooth_disabled_rounded,
                                            size: 18,
                                            color: btGranted ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Bluetooth Thermal Printer Access',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                          ),
                                        ],
                                      ),
                                      if (!btGranted)
                                        TextButton(
                                          onPressed: () async {
                                            await PermissionService().requestBluetoothPermissions();
                                            setSheetState(() {});
                                          },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            backgroundColor: const Color(0xFF0F172A),
                                            foregroundColor: Colors.white,
                                            minimumSize: Size.zero,
                                          ),
                                          child: const Text('Allow', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // --- 2. LOW STOCK ALERT CARD ---
                        if (lowStock > 0)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$lowStock Items Running Low',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF991B1B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Tap to review and quickly restock inventory',
                                        style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _openLowStockRestockSheet();
                                  },
                                  child: const Text('Restock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),

                        // --- 3. RECENT IN-APP NOTIFICATIONS FEED ---
                        ValueListenableBuilder<List<AppNotificationItem>>(
                          valueListenable: NotificationService().notificationsNotifier,
                          builder: (context, items, _) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Recent Store Notifications (${items.length})',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (items.isNotEmpty)
                                      TextButton(
                                        onPressed: () {
                                          NotificationService().clearAll();
                                          setSheetState(() {});
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(0xFF64748B),
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                        ),
                                        child: const Text('Clear All', style: TextStyle(fontSize: 12)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (items.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: const Column(
                                      children: [
                                        Icon(Icons.mark_email_read_outlined, color: Color(0xFF94A3B8), size: 36),
                                        SizedBox(height: 8),
                                        Text(
                                          'No new notifications',
                                          style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 13),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Order receipts, stock warnings and sync alerts appear here and in your phone status bar.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ...items.map((item) {
                                    final timeStr = '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.02),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: item.color.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(item.icon, color: item.color, size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        item.title,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      timeStr,
                                                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  item.message,
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        // --- 4. CLOUD SYNC ACTIVE CARD ---
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.cloud_done_rounded, color: Color(0xFF16A34A), size: 22),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Offline Auto-Sync & Push Live',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF166534)),
                                    ),
                                    Text(
                                      'Orders and catalog queue sync continuously with the cloud database',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }
}