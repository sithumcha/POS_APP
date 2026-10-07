import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'product_image_widget.dart';

class ProductDetailSheet extends StatefulWidget {
  final Map<String, dynamic> productSummary;
  final Function(Map<String, dynamic> cartItem) onAddToCart;

  const ProductDetailSheet({
    super.key,
    required this.productSummary,
    required this.onAddToCart,
  });

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  Map<String, dynamic>? _fullProduct;
  int _quantity = 1;

  // Selected variations state map
  // Single type: { "Size": "Regular" }
  // Multiple type: { "Add-ons": ["Extra Shot Espresso", "Whipped Cream"] }
  final Map<String, dynamic> _selectedVariations = {};

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
  }

  Future<void> _fetchProductDetails() async {
    final productId = widget.productSummary['id'] ?? 101;
    try {
      final data = await _apiService.getProductById(productId);
      if (!mounted) return;
      setState(() {
        _fullProduct = data;
        _isLoading = false;

        // Initialize default variation selections
        if (data['variations'] != null) {
          for (var v in data['variations']) {
            final name = v['name'] as String;
            final type = v['type'] as String;
            final options = (v['options'] as List);
            if (type == 'single' && options.isNotEmpty) {
              _selectedVariations[name] = options.first['label'];
            } else if (type == 'multiple') {
              _selectedVariations[name] = <String>[];
            }
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fullProduct = widget.productSummary;
        _isLoading = false;
      });
    }
  }

  double _calculateTotalUnitPrice() {
    if (_fullProduct == null) return 0.0;

    final double basePrice = (_fullProduct!['discount_price'] ?? _fullProduct!['base_price'] ?? 0.0).toDouble();
    double variationsAddonTotal = 0.0;

    final variations = _fullProduct!['variations'] as List? ?? [];
    for (var v in variations) {
      final name = v['name'] as String;
      final type = v['type'] as String;
      final options = v['options'] as List? ?? [];

      if (type == 'single') {
        final selectedLabel = _selectedVariations[name];
        for (var opt in options) {
          if (opt['label'] == selectedLabel) {
            variationsAddonTotal += (opt['price_modifier'] ?? 0.0).toDouble();
          }
        }
      } else if (type == 'multiple') {
        final List selectedLabels = _selectedVariations[name] ?? [];
        for (var opt in options) {
          if (selectedLabels.contains(opt['label'])) {
            variationsAddonTotal += (opt['price_modifier'] ?? 0.0).toDouble();
          }
        }
      }
    }

    return (basePrice + variationsAddonTotal) * _quantity;
  }

  @override
  Widget build(BuildContext context) {
    final item = _fullProduct ?? widget.productSummary;
    final double unitPrice = (item['discount_price'] ?? item['base_price'] ?? 0.0).toDouble();
    final double? originalPrice = item['discount_price'] != null ? (item['base_price'] ?? 0.0).toDouble() : null;
    final String name = item['name'] ?? 'Item Name';
    final String sku = item['sku'] ?? 'SKU-000';
    final String? description = item['full_description'] ?? item['description'];
    final List tags = item['tags'] ?? ['Popular'];
    final List variations = item['variations'] ?? [];

    final double totalPrice = _calculateTotalUnitPrice();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle & top bar
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Product Quick View',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(
                child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProductImageWidget(
                      imageUrl: item['main_image'] ?? (item['images'] is List && (item['images'] as List).isNotEmpty ? item['images'][0] : null),
                      productName: name,
                      width: double.infinity,
                      height: 180,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    const SizedBox(height: 16),

                    // Title & Price Header
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'SKU: $sku',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Rs. ${unitPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                            if (originalPrice != null)
                              Text(
                                'Rs. ${originalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // --- 2. TAGS CHIPS ---
                    if (tags.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              '# $tag',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // --- 3. FULL DESCRIPTION ---
                    if (description != null && description.isNotEmpty) ...[
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 14),

                    // --- 4. VARIATIONS SECTION ---
                    if (variations.isNotEmpty) ...[
                      const Text(
                        'Customize & Variations',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...variations.map((v) => _buildVariationGroup(v)),
                      const SizedBox(height: 10),
                    ],

                    // --- 5. QUANTITY STEPPER ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Quantity',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _quantity > 1
                                    ? () {
                                        setState(() {
                                          _quantity--;
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.remove_rounded, size: 20),
                                color: Colors.black,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '$_quantity',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _quantity++;
                                  });
                                },
                                icon: const Icon(Icons.add_rounded, size: 20),
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

          // --- 6. ADD TO CART BOTTOM ACTION BAR ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: () {
                  final cartItem = {
                    'product_id': item['id'],
                    'name': name,
                    'unit_price': (totalPrice / _quantity),
                    'quantity': _quantity,
                    'total_price': totalPrice,
                    'variations': Map<String, dynamic>.from(_selectedVariations),
                  };
                  Navigator.pop(context);
                  widget.onAddToCart(cartItem);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add to Cart',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Rs. ${totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildVariationGroup(Map<String, dynamic> v) {
    final String groupName = v['name'] ?? 'Variation';
    final String type = v['type'] ?? 'single';
    final List options = v['options'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                groupName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                type == 'single' ? '(Select 1)' : '(Optional)',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final String label = opt['label'];
              final double modifier = (opt['price_modifier'] ?? 0.0).toDouble();

              bool isSelected = false;
              if (type == 'single') {
                isSelected = _selectedVariations[groupName] == label;
              } else {
                final List list = _selectedVariations[groupName] ?? [];
                isSelected = list.contains(label);
              }

              return InkWell(
                onTap: () {
                  setState(() {
                    if (type == 'single') {
                      _selectedVariations[groupName] = label;
                    } else {
                      final List list = List<String>.from(_selectedVariations[groupName] ?? []);
                      if (list.contains(label)) {
                        list.remove(label);
                      } else {
                        list.add(label);
                      }
                      _selectedVariations[groupName] = list;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.black : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                      if (modifier > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '+Rs. ${modifier.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white70 : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
