import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProduct;

  const ProductFormScreen({
    super.key,
    this.initialProduct,
  });

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Categories & Subcategories lists from API
  List<dynamic> _categories = [];
  List<dynamic> _subcategories = [];

  bool _isLoadingCategories = true;
  bool _isLoadingSubcategories = false;
  bool _isSaving = false;

  // Form Fields State Controllers
  int? _selectedCategoryId;
  int? _selectedSubcategoryId;

  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _shortDescController;
  late final TextEditingController _fullDescController;
  late final TextEditingController _priceController;
  late final TextEditingController _discountPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _mainImageController;

  // Secondary Images List
  final List<String> _secondaryImages = [];
  final TextEditingController _secondaryImageInputController = TextEditingController();

  // Toggles
  bool _statusActive = true;
  bool _isFeatured = false;

  bool get _isEditMode => widget.initialProduct != null;

  // Catalog Preset Images for quick selection
  final List<Map<String, String>> _presetImages = [
    {
      'title': 'Wireless Mouse',
      'url': 'https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=500&auto=format&fit=crop&q=60',
    },
    {
      'title': 'Smartphone',
      'url': 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500&auto=format&fit=crop&q=60',
    },
    {
      'title': 'Espresso Coffee',
      'url': 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=500&auto=format&fit=crop&q=60',
    },
    {
      'title': 'Ceylon Tea',
      'url': 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=500&auto=format&fit=crop&q=60',
    },
    {
      'title': 'Butter Croissant',
      'url': 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=500&auto=format&fit=crop&q=60',
    },
    {
      'title': 'Mechanical Keyboard',
      'url': 'https://images.unsplash.com/photo-1587829741301-dc798b83add3?w=500&auto=format&fit=crop&q=60',
    },
    {
      'title': 'Headphones',
      'url': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500&auto=format&fit=crop&q=60',
    },
    {
      'title': 'Bakery Snacks',
      'url': 'https://images.unsplash.com/photo-1621939514649-280e2ee25f60?w=500&auto=format&fit=crop&q=60',
    },
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;

    _nameController = TextEditingController(text: p?['name'] ?? '');
    _skuController = TextEditingController(text: p?['sku'] ?? '');
    _shortDescController = TextEditingController(text: p?['short_description'] ?? '');
    _fullDescController = TextEditingController(text: p?['full_description'] ?? p?['description'] ?? '');

    _priceController = TextEditingController(
      text: p != null ? (p['base_price'] ?? p['price'] ?? 0).toString() : '',
    );
    _discountPriceController = TextEditingController(
      text: (p != null && p['discount_price'] != null) ? p['discount_price'].toString() : '',
    );
    _stockController = TextEditingController(
      text: p != null ? (p['stock'] ?? 10).toString() : '10',
    );
    _mainImageController = TextEditingController(text: p?['main_image'] ?? '');

    if (p?['images'] is List) {
      _secondaryImages.addAll((p!['images'] as List).map((e) => e.toString()));
    }

    final rawStatus = p?['status'];
    _statusActive = rawStatus is bool
        ? rawStatus
        : (rawStatus is String ? (rawStatus.toLowerCase() == 'active' || rawStatus == '1') : true);
    _isFeatured = p?['featured'] ?? false;

    _selectedCategoryId = p?['category_id'] ?? p?['categoryId'];
    _selectedSubcategoryId = p?['subcategory_id'] ?? p?['subCategoryId'];

    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _shortDescController.dispose();
    _fullDescController.dispose();
    _priceController.dispose();
    _discountPriceController.dispose();
    _stockController.dispose();
    _mainImageController.dispose();
    _secondaryImageInputController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _apiService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _isLoadingCategories = false;
      });

      if (_selectedCategoryId != null) {
        _loadSubcategories(_selectedCategoryId!);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _loadSubcategories(int categoryId) async {
    setState(() {
      _isLoadingSubcategories = true;
    });
    try {
      final subs = await _apiService.getSubcategories(categoryId: categoryId);
      if (!mounted) return;
      setState(() {
        _subcategories = subs;
        _isLoadingSubcategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subcategories = [];
        _isLoadingSubcategories = false;
      });
    }
  }

  void _onCategoryChanged(int? newCatId) {
    setState(() {
      _selectedCategoryId = newCatId;
      _selectedSubcategoryId = null;
      _subcategories = [];
    });
    if (newCatId != null) {
      _loadSubcategories(newCatId);
    }
  }

  void _addSecondaryImage(String url) {
    final cleanUrl = url.trim();
    if (cleanUrl.isNotEmpty) {
      setState(() {
        _secondaryImages.add(cleanUrl);
        _secondaryImageInputController.clear();
      });
    }
  }

  void _removeSecondaryImage(int index) {
    setState(() {
      _secondaryImages.removeAt(index);
    });
  }

  void _openImagePickerModal({required Function(String url) onImageSelected}) {
    final urlController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Product Image',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Upload Source Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildPickerOptionTile(
                      icon: Icons.photo_library_rounded,
                      label: 'Upload from Gallery',
                      color: const Color(0xFF2563EB),
                      onTap: () {
                        // Demo gallery pick - selects default high res product image
                        onImageSelected(
                          'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500&auto=format&fit=crop&q=60',
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Image uploaded from Gallery!'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildPickerOptionTile(
                      icon: Icons.camera_alt_rounded,
                      label: 'Take Photo',
                      color: const Color(0xFF16A34A),
                      onTap: () {
                        // Demo camera capture - selects photo stream image
                        onImageSelected(
                          'https://images.unsplash.com/photo-1560343090-f0409e92791a?w=500&auto=format&fit=crop&q=60',
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Photo captured with Camera!'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Preset Stock Photos Section
              const Text(
                'Or Choose Sample Product Photo',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 10),

              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _presetImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = _presetImages[index];
                    return GestureDetector(
                      onTap: () {
                        onImageSelected(item['url']!);
                        Navigator.pop(context);
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.network(
                                item['url']!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['title']!,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Manual URL Input Fallback
              const Text(
                'Enter Image Web URL Link',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        hintText: 'https://...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      if (urlController.text.trim().isNotEmpty) {
                        onImageSelected(urlController.text.trim());
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Use Link'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPickerOptionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSaveProduct() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields correctly.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Category'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final double basePrice = double.tryParse(_priceController.text.trim()) ?? 0.0;
    final double? discountPrice = _discountPriceController.text.trim().isNotEmpty
        ? double.tryParse(_discountPriceController.text.trim())
        : null;
    final int stock = int.tryParse(_stockController.text.trim()) ?? 10;

    final Map<String, dynamic> payload = {
      'category_id': _selectedCategoryId,
      'subcategory_id': _selectedSubcategoryId,
      'name': _nameController.text.trim(),
      'sku': _skuController.text.trim().isNotEmpty
          ? _skuController.text.trim()
          : 'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      'price': basePrice,
      'base_price': basePrice,
      'discount_price': discountPrice,
      'stock': stock,
      'status': _statusActive ? 'active' : 'inactive',
      'featured': _isFeatured,
      'short_description': _shortDescController.text.trim(),
      'full_description': _fullDescController.text.trim(),
      'main_image': _mainImageController.text.trim().isNotEmpty ? _mainImageController.text.trim() : null,
      'images': _secondaryImages,
    };

    try {
      if (_isEditMode) {
        final id = widget.initialProduct!['id'];
        await _apiService.updateProduct(id, payload);
      } else {
        await _apiService.createProduct(payload);
      }

      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode ? 'Product updated successfully!' : 'Product created successfully!',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save product: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode ? 'Edit Product Details' : 'Add New Product',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 1. CATEGORY & SUBCATEGORY SELECTION ---
              _buildSectionHeader('Category Classification'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardBoxDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Category *', style: _labelTextStyle),
                    const SizedBox(height: 6),
                    _isLoadingCategories
                        ? const Center(child: CircularProgressIndicator(color: Colors.black))
                        : DropdownButtonFormField<int>(
                            value: _selectedCategoryId,
                            hint: const Text('Select a Category'),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            items: _categories.map((cat) {
                              return DropdownMenuItem<int>(
                                value: cat['id'] as int,
                                child: Text(cat['name'] ?? 'Category'),
                              );
                            }).toList(),
                            onChanged: _onCategoryChanged,
                            validator: (val) => val == null ? 'Category selection required' : null,
                          ),
                    const SizedBox(height: 16),

                    const Text('Subcategory (Optional)', style: _labelTextStyle),
                    const SizedBox(height: 6),
                    _isLoadingSubcategories
                        ? const Center(child: CircularProgressIndicator(color: Colors.black))
                        : DropdownButtonFormField<int>(
                            value: _selectedSubcategoryId,
                            hint: Text(
                              _selectedCategoryId == null
                                  ? 'Select a Category first'
                                  : (_subcategories.isEmpty ? 'No Subcategories Available' : 'Select Subcategory'),
                            ),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            items: _subcategories.map((subcat) {
                              return DropdownMenuItem<int>(
                                value: subcat['id'] as int,
                                child: Text(subcat['name'] ?? 'Subcategory'),
                              );
                            }).toList(),
                            onChanged: _selectedCategoryId == null || _subcategories.isEmpty
                                ? null
                                : (val) {
                                    setState(() {
                                      _selectedSubcategoryId = val;
                                    });
                                  },
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- 2. BASIC PRODUCT DETAILS ---
              _buildSectionHeader('Product Info & SKU'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardBoxDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Product Name *', style: _labelTextStyle),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(hintText: 'e.g. Wireless Ergonomic Mouse'),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Product name required' : null,
                    ),
                    const SizedBox(height: 16),

                    const Text('SKU / Barcode Code', style: _labelTextStyle),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _skuController,
                      decoration: const InputDecoration(hintText: 'e.g. WM-001 or barcode number'),
                    ),
                    const SizedBox(height: 16),

                    const Text('Short Summary Description', style: _labelTextStyle),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _shortDescController,
                      decoration: const InputDecoration(hintText: 'Brief single line description'),
                    ),
                    const SizedBox(height: 16),

                    const Text('Full Detailed Description', style: _labelTextStyle),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _fullDescController,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'Detailed specifications & info'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- 3. PRICING & STOCK ---
              _buildSectionHeader('Pricing & Inventory'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardBoxDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Regular Price (LKR) *', style: _labelTextStyle),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: '1500.00'),
                                validator: (val) => (val == null || val.trim().isEmpty) ? 'Price required' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Discount Price (LKR)', style: _labelTextStyle),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _discountPriceController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: '1250.00'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Available Stock Count *', style: _labelTextStyle),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'e.g. 25'),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Stock level required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- 4. IMAGE UPLOAD & SELECTION ---
              _buildSectionHeader('Product Images (Gallery / Camera / Presets)'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardBoxDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Main Cover Image', style: _labelTextStyle),
                        TextButton.icon(
                          onPressed: () => _openImagePickerModal(
                            onImageSelected: (url) {
                              setState(() {
                                _mainImageController.text = url;
                              });
                            },
                          ),
                          icon: const Icon(Icons.add_a_photo_rounded, size: 16, color: Colors.black),
                          label: const Text('Choose Image', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Main Image Preview Container
                    GestureDetector(
                      onTap: () => _openImagePickerModal(
                        onImageSelected: (url) {
                          setState(() {
                            _mainImageController.text = url;
                          });
                        },
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: _mainImageController.text.trim().isNotEmpty
                            ? Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(13),
                                      child: Image.network(
                                        _mainImageController.text.trim(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildImagePlaceholder('Invalid Image URL'),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.75),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                                          SizedBox(width: 4),
                                          Text('Change', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.add_a_photo_rounded, size: 28, color: Colors.black),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Tap to Upload Image (Gallery / Camera)',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Secondary Images Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Additional Gallery Images', style: _labelTextStyle),
                        TextButton.icon(
                          onPressed: () => _openImagePickerModal(
                            onImageSelected: (url) => _addSecondaryImage(url),
                          ),
                          icon: const Icon(Icons.add_photo_alternate_rounded, size: 16, color: Colors.black),
                          label: const Text('Add Image', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_secondaryImages.isNotEmpty)
                      SizedBox(
                        height: 90,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _secondaryImages.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: Image.network(
                                      _secondaryImages[index],
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeSecondaryImage(index),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                            SizedBox(width: 8),
                            Text(
                              'No additional images added yet.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- 5. TOGGLES (STATUS & FEATURED) ---
              _buildSectionHeader('Status & Display Toggles'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: _cardBoxDecoration(),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Product Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        _statusActive ? 'Active (Visible in POS Catalog)' : 'Inactive (Hidden)',
                        style: TextStyle(
                          fontSize: 12,
                          color: _statusActive ? AppColors.success : AppColors.error,
                        ),
                      ),
                      value: _statusActive,
                      activeColor: Colors.black,
                      onChanged: (val) => setState(() => _statusActive = val),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Featured Product', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      subtitle: const Text('Show badge on catalog grid', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      value: _isFeatured,
                      activeColor: Colors.black,
                      onChanged: (val) => setState(() => _isFeatured = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- 6. BOTTOM SAVE PRODUCT BUTTON ---
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSaveProduct,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                label: Text(
                  _isSaving
                      ? 'Saving Product...'
                      : (_isEditMode ? 'Update Product Details' : 'Save Product'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: Colors.black,
        letterSpacing: -0.3,
      ),
    );
  }

  BoxDecoration _cardBoxDecoration() {
    return BoxDecoration(
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
    );
  }

  Widget _buildImagePlaceholder(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_outlined, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

const TextStyle _labelTextStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.bold,
  color: Colors.black,
);
