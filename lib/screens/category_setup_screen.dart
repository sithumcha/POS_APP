import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../theme/responsive.dart';
import '../widgets/ui_animation_helper.dart';

class CategorySetupScreen extends StatefulWidget {
  const CategorySetupScreen({super.key});

  @override
  State<CategorySetupScreen> createState() => _CategorySetupScreenState();
}

class _CategorySetupScreenState extends State<CategorySetupScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ApiService _apiService = ApiService();

  // Tab 1: Categories State
  List<dynamic> _categories = [];
  bool _isLoadingCategories = true;

  // Tab 2: Subcategories State
  List<dynamic> _subcategories = [];
  bool _isLoadingSubcategories = true;

  int? _selectedFilterParentCategoryId; // null = All Parent Categories

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 1. INITIAL BATCH LOADING:
  /// Concurrently loads both main categories and subcategories from backend API.
  Future<void> _loadAllData() async {
    final isStaff = await _apiService.isStaffUser();
    if (isStaff) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Restricted: Only Store Owner / Admin can manage categories.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
      return;
    }

    await Future.wait([
      _loadCategories(),
      _loadSubcategories(),
    ]);
  }

  /// 2. CATEGORY ICON / IMAGE UPLOAD LOGIC:
  /// Uses ImagePicker to select image from gallery, converts to bytes,
  /// uploads to API storage endpoint, and updates image URL field.
  Future<void> _pickAndUploadImage({
    required StateSetter setModalState,
    required TextEditingController imageCtrl,
    required Function(bool isUploading) setUploading,
  }) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;

      setUploading(true);

      final bytes = await file.readAsBytes();
      final filename = file.name.isNotEmpty ? file.name : 'cat_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final res = await _apiService.uploadImage(bytes, filename);

      setUploading(false);

      if (res['success'] == true && res['url'] != null && (res['url'] as String).isNotEmpty) {
        setModalState(() {
          imageCtrl.text = res['url'] as String;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Failed to upload image.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setUploading(false);
      debugPrint('Error picking category image: $e');
    }
  }

  /// 3. FETCH CATEGORIES (GET /categories):
  /// Retrieves parent category list and updates UI state.
  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });
    try {
      final cats = await _apiService.getCategories(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _categories = cats;
        _isLoadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  // --- API: GET /subcategories ---
  Future<void> _loadSubcategories() async {
    setState(() {
      _isLoadingSubcategories = true;
    });
    try {
      final subcats = await _apiService.getSubcategories(
        categoryId: _selectedFilterParentCategoryId,
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() {
        _subcategories = subcats;
        _isLoadingSubcategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingSubcategories = false;
      });
    }
  }

  // --- API: DELETE /categories/{id} ---
  Future<void> _deleteCategory(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Delete Category', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to delete category "$name"? Products inside this category may lose their mapping.'),
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
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _apiService.deleteCategory(id);
      if (success) {
        await _loadCategories();
        await _loadSubcategories();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$name" deleted.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- API: DELETE /subcategories/{id} ---
  Future<void> _deleteSubcategory(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Delete Subcategory', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to delete subcategory "$name"?'),
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
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _apiService.deleteSubcategory(id);
      if (success) {
        await _loadSubcategories();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subcategory "$name" deleted.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _parseStatus(dynamic status) {
    if (status == null) return true;
    if (status is bool) return status;
    if (status is String) {
      final s = status.toLowerCase();
      return s == 'active' || s == 'true' || s == '1';
    }
    if (status is num) return status == 1;
    return true;
  }

  // --- API: POST /categories OR PUT /categories/{id} MODAL SHEET ---
  void _showCategoryModalForm({Map<String, dynamic>? initialCategory}) {
    final bool isEdit = initialCategory != null;
    final nameCtrl = TextEditingController(text: isEdit ? initialCategory['name'] : '');
    final slugCtrl = TextEditingController(text: isEdit ? (initialCategory['slug'] ?? '') : '');
    final imageCtrl = TextEditingController(text: isEdit ? (initialCategory['image'] ?? '') : '');
    final descCtrl = TextEditingController(text: isEdit ? (initialCategory['description'] ?? '') : '');
    bool isActive = isEdit ? _parseStatus(initialCategory['status']) : true;
    bool isUploadingImage = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ResponsiveCenter(
              maxWidth: 560,
              child: Padding(
                padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Edit Category' : 'Add Category',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Category Name
                  TextField(
                    controller: nameCtrl,
                    onChanged: (val) {
                      if (!isEdit && slugCtrl.text.isEmpty) {
                        slugCtrl.text = val.toLowerCase().replaceAll(' ', '-').replaceAll(RegExp(r'[^a-z0-9\-]'), '');
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Category Name *', hintText: 'e.g. Beverages'),
                  ),
                  const SizedBox(height: 12),

                  // Slug
                  TextField(
                    controller: slugCtrl,
                    decoration: const InputDecoration(labelText: 'Slug *', hintText: 'e.g. beverages'),
                  ),
                  const SizedBox(height: 12),

                  // Image Upload Box
                  const Text('Category Image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: isUploadingImage
                        ? null
                        : () => _pickAndUploadImage(
                              setModalState: setModalState,
                              imageCtrl: imageCtrl,
                              setUploading: (val) => setModalState(() => isUploadingImage = val),
                            ),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 110,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: imageCtrl.text.isNotEmpty ? Colors.black : const Color(0xFFCBD5E1),
                          width: imageCtrl.text.isNotEmpty ? 1.5 : 1.0,
                        ),
                      ),
                      child: isUploadingImage
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
                                  SizedBox(height: 8),
                                  Text('Uploading image...', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                ],
                              ),
                            )
                          : imageCtrl.text.isNotEmpty
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(13),
                                      child: Image.network(
                                        imageCtrl.text,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.broken_image_outlined, size: 36, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            imageCtrl.clear();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.75),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                                            SizedBox(width: 4),
                                            Text('Change Image', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.black87),
                                    SizedBox(height: 6),
                                    Text('Tap to Select & Upload Image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                                    SizedBox(height: 2),
                                    Text('Supports PNG, JPG, WEBP formats', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description', hintText: 'Short category description...'),
                  ),
                  const SizedBox(height: 12),

                  // Status Toggle
                  SwitchListTile(
                    title: const Text('Active Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    value: isActive,
                    activeColor: Colors.black,
                    onChanged: (val) {
                      setModalState(() {
                        isActive = val;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;

                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);

                      final payload = {
                        'name': name,
                        'slug': slugCtrl.text.trim().isEmpty ? name.toLowerCase().replaceAll(' ', '-') : slugCtrl.text.trim(),
                        'image': imageCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'status': isActive ? 'active' : 'inactive',
                      };

                      if (isEdit) {
                        final id = int.tryParse(initialCategory['id']?.toString() ?? '') ?? 0;
                        await _apiService.updateCategory(id, payload);
                        await _loadCategories();
                      } else {
                        await _apiService.createCategory(payload);
                        await _loadCategories();
                      }

                      nav.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(isEdit ? 'Category updated!' : 'Category created successfully!'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isEdit ? 'Update Category' : 'Save Category'),
                  ),
                ],
              ),
            ),
          );
        },
        );
      },
    );
  }

  // --- API: POST /subcategories OR PUT /subcategories/{id} MODAL SHEET ---
  void _showSubcategoryModalForm({Map<String, dynamic>? initialSubcategory}) {
    final bool isEdit = initialSubcategory != null;

    // Filter genuine server categories (id > 0 and <= 2,147,483,647)
    final validCategories = _categories.where((c) {
      final cid = int.tryParse(c['id']?.toString() ?? '') ?? 0;
      return cid > 0 && cid <= 2147483647;
    }).toList();

    if (validCategories.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 24),
              SizedBox(width: 8),
              Text('Parent Category Required', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: const Text(
            'You must create at least one Parent Category before adding subcategories.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _tabController.animateTo(0);
                _showCategoryModalForm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Create Category'),
            ),
          ],
        ),
      );
      return;
    }

    int? selectedParentId;
    if (isEdit) {
      final dynamic rawCat = initialSubcategory['category_id'] ??
          initialSubcategory['categoryId'] ??
          (initialSubcategory['category'] is Map ? initialSubcategory['category']['id'] : null) ??
          initialSubcategory['parent_id'] ??
          initialSubcategory['parentId'];
      selectedParentId = int.tryParse(rawCat?.toString() ?? '');
    }

    final seenIds = <int>{};
    final List<DropdownMenuItem<int>> dropdownItems = [];
    for (final c in validCategories) {
      final cid = int.parse(c['id'].toString());
      if (!seenIds.contains(cid)) {
        seenIds.add(cid);
        dropdownItems.add(
          DropdownMenuItem<int>(
            value: cid,
            child: Text(
              c['name']?.toString() ?? 'Category #$cid',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
    }

    if (selectedParentId == null || !seenIds.contains(selectedParentId)) {
      if (_selectedFilterParentCategoryId != null && seenIds.contains(_selectedFilterParentCategoryId)) {
        selectedParentId = _selectedFilterParentCategoryId;
      } else if (seenIds.isNotEmpty) {
        selectedParentId = seenIds.first;
      }
    }

    final nameCtrl = TextEditingController(text: isEdit ? (initialSubcategory['name']?.toString() ?? '') : '');
    final slugCtrl = TextEditingController(text: isEdit ? (initialSubcategory['slug']?.toString() ?? '') : '');
    final imageCtrl = TextEditingController(text: isEdit ? (initialSubcategory['image']?.toString() ?? '') : '');
    bool isUploadingImage = false;
    bool isSaving = false;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ResponsiveCenter(
              maxWidth: 560,
              child: Padding(
                padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEdit ? 'Edit Subcategory' : 'Add Subcategory',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Parent Category Dropdown
                  const Text('Parent Category *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedParentId,
                    decoration: const InputDecoration(filled: true, fillColor: Color(0xFFF8FAFC)),
                    items: dropdownItems,
                    onChanged: (val) {
                      setModalState(() {
                        selectedParentId = val;
                        modalError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Subcategory Name
                  TextField(
                    controller: nameCtrl,
                    onChanged: (val) {
                      if (!isEdit && slugCtrl.text.isEmpty) {
                        slugCtrl.text = val.toLowerCase().replaceAll(' ', '-').replaceAll(RegExp(r'[^a-z0-9\-]'), '');
                      }
                      if (modalError != null) {
                        setModalState(() => modalError = null);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Subcategory Name *', hintText: 'e.g. Hot Drinks'),
                  ),
                  const SizedBox(height: 12),

                  // Slug
                  TextField(
                    controller: slugCtrl,
                    decoration: const InputDecoration(labelText: 'Slug *', hintText: 'e.g. hot-drinks'),
                  ),
                  const SizedBox(height: 12),

                  // Image Upload Box
                  const Text('Subcategory Image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: isUploadingImage
                        ? null
                        : () => _pickAndUploadImage(
                              setModalState: setModalState,
                              imageCtrl: imageCtrl,
                              setUploading: (val) => setModalState(() => isUploadingImage = val),
                            ),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 110,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: imageCtrl.text.isNotEmpty ? Colors.black : const Color(0xFFCBD5E1),
                          width: imageCtrl.text.isNotEmpty ? 1.5 : 1.0,
                        ),
                      ),
                      child: isUploadingImage
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)),
                                  SizedBox(height: 8),
                                  Text('Uploading image...', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                ],
                              ),
                            )
                          : imageCtrl.text.isNotEmpty
                              ? Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(13),
                                      child: Image.network(
                                        imageCtrl.text,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.broken_image_outlined, size: 36, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            imageCtrl.clear();
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 6,
                                      left: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.75),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                                            SizedBox(width: 4),
                                            Text('Change Image', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.black87),
                                    SizedBox(height: 6),
                                    Text('Tap to Select & Upload Image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                                    SizedBox(height: 2),
                                    Text('Supports PNG, JPG, WEBP formats', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (modalError != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              modalError!,
                              style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              setModalState(() => modalError = 'Please enter a subcategory name.');
                              return;
                            }

                            if (selectedParentId == null || selectedParentId! <= 0 || selectedParentId! > 2147483647) {
                              setModalState(() => modalError = 'Please select a valid parent category.');
                              return;
                            }

                            final int parentIdToSave = selectedParentId!;
                            final parentCat = validCategories.firstWhere(
                              (c) => int.tryParse(c['id']?.toString() ?? '') == parentIdToSave,
                              orElse: () => <String, dynamic>{},
                            );
                            final parentCatName = parentCat['name']?.toString();

                            setModalState(() {
                              isSaving = true;
                              modalError = null;
                            });
                            final messenger = ScaffoldMessenger.of(context);
                            final nav = Navigator.of(context);

                            final payload = {
                              'category_id': parentIdToSave,
                              'categoryId': parentIdToSave,
                              if (parentCatName != null) 'category_name': parentCatName,
                              'name': name,
                              'slug': slugCtrl.text.trim().isEmpty
                                  ? name.toLowerCase().replaceAll(' ', '-')
                                  : slugCtrl.text.trim(),
                              if (imageCtrl.text.trim().isNotEmpty)
                                'image': imageCtrl.text.trim(),
                              'description': name,
                              'status': 'active',
                            };

                            Map<String, dynamic> result;
                            if (isEdit) {
                              final id = int.tryParse(initialSubcategory['id']?.toString() ?? '0') ?? 0;
                              result = await _apiService.updateSubcategory(id, payload);
                            } else {
                              result = await _apiService.createSubcategory(payload);
                            }

                            if (!mounted) return;

                            if (result['success'] != true) {
                              setModalState(() {
                                isSaving = false;
                                modalError = result['message']?.toString() ?? 'Failed to save subcategory';
                              });
                              return;
                            }

                            // Reload real subcategories from live backend database
                            await _loadSubcategories();

                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(isEdit ? 'Subcategory updated in DB!' : 'Subcategory created in DB successfully!'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(isEdit ? 'Update Subcategory' : 'Save Subcategory'),
                  ),
                ],
              ),
            ),
          );
        },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Categories & Subcategories Setup',
          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF0F172A), fontWeight: FontWeight.w800, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0F172A),
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: const Color(0xFF0F172A),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Categories'),
            Tab(text: 'Subcategories'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- TAB 1: CATEGORIES MANAGEMENT ---
          _buildCategoriesTab(),

          // --- TAB 2: SUBCATEGORIES MANAGEMENT ---
          _buildSubcategoriesTab(),
        ],
      ),
    );
  }

  // --- TAB 1 BUILDER ---
  Widget _buildCategoriesTab() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : _categories.isEmpty
              ? _buildEmptyState('No parent categories found', 'Tap + to create a category')
              : ResponsiveCenter(
                  maxWidth: 900,
                  child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _categories[index];
                    final int id = int.tryParse(item['id']?.toString() ?? '') ?? 0;
                    final String name = item['name'] ?? 'Category';
                    final String slug = item['slug'] ?? name.toLowerCase().replaceAll(' ', '-');
                    final String? image = item['image'];
                    final bool isActive = _parseStatus(item['status']);

                    return FadeSlideEntrance(
                      delay: Duration(milliseconds: 30 * (index % 10)),
                      child: HoverScaleCard(
                        padding: const EdgeInsets.all(12),
                        borderRadius: BorderRadius.circular(16),
                        scaleFactor: 1.018,
                        child: Row(
                          children: [
                            // Category Thumbnail Preview
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: image != null && image.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        image,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.category_outlined, color: AppColors.textMuted),
                                      ),
                                    )
                                  : const Icon(Icons.category_outlined, color: AppColors.textMuted, size: 26),
                            ),
                            const SizedBox(width: 14),

                            // Name, Slug & Status
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Slug: /$slug',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),

                            // Edit & Delete Actions
                            AnimatedTapButton(
                              scaleDown: 0.88,
                              onTap: () => _showCategoryModalForm(initialCategory: item),
                              child: const Padding(
                                padding: EdgeInsets.all(6.0),
                                child: Icon(Icons.edit_outlined, size: 20, color: Colors.black),
                              ),
                            ),
                            AnimatedTapButton(
                              scaleDown: 0.88,
                              onTap: () => _deleteCategory(id, name),
                              child: const Padding(
                                padding: EdgeInsets.all(6.0),
                                child: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryModalForm(),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- TAB 2 BUILDER ---
  Widget _buildSubcategoriesTab() {
    final filteredSubcats = _selectedFilterParentCategoryId == null
        ? _subcategories
        : _subcategories.where((s) {
            final pid = s['categoryId']?.toString() ?? s['category_id']?.toString() ?? '';
            return pid == _selectedFilterParentCategoryId.toString();
          }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveCenter(
        maxWidth: 900,
        child: Column(
        children: [
          // Filter Dropdown by Parent Category
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.filter_list_rounded, size: 20, color: Colors.black),
                const SizedBox(width: 8),
                const Text('Parent Filter:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: _selectedFilterParentCategoryId,
                        isExpanded: true,
                        hint: const Text('All Parent Categories', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('All Parent Categories', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                          ..._categories.where((c) => (int.tryParse(c['id']?.toString() ?? '') ?? 0) > 0).map((c) {
                            final cid = int.parse(c['id'].toString());
                            return DropdownMenuItem<int?>(
                              value: cid,
                              child: Text(c['name']?.toString() ?? 'Category #$cid', style: const TextStyle(fontSize: 13)),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedFilterParentCategoryId = val;
                          });
                          _loadSubcategories();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          Expanded(
            child: _isLoadingSubcategories
                ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : filteredSubcats.isEmpty
                    ? _buildEmptyState('No subcategories found', 'Tap + to add a subcategory')
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredSubcats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filteredSubcats[index];
                          final int id = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
                          final String name = item['name']?.toString() ?? 'Subcategory';
                          final String slug = item['slug']?.toString() ?? name.toLowerCase().replaceAll(' ', '-');
                          final String parentIdStr = (item['category_id'] ?? item['categoryId'] ?? '').toString();
                          final parentCat = _categories.firstWhere(
                            (c) => c['id']?.toString() == parentIdStr,
                            orElse: () => {'name': item['category_name']?.toString() ?? 'Parent Category'},
                          );
                          final String parentName = parentCat['name']?.toString() ?? 'Parent Category';
                          final String? image = item['image']?.toString();

                          return FadeSlideEntrance(
                            delay: Duration(milliseconds: 30 * (index % 10)),
                            child: HoverScaleCard(
                              padding: const EdgeInsets.all(12),
                              borderRadius: BorderRadius.circular(16),
                              scaleFactor: 1.018,
                              onTap: () => _showSubcategoryModalForm(initialSubcategory: Map<String, dynamic>.from(item)),
                              child: Row(
                                children: [
                                  // Image Thumbnail
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: image != null && image.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              image,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.subdirectory_arrow_right_rounded, color: AppColors.textMuted),
                                            ),
                                          )
                                        : const Icon(Icons.subdirectory_arrow_right_rounded, color: AppColors.textMuted, size: 24),
                                  ),
                                  const SizedBox(width: 14),

                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Parent: $parentName • /$slug',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Edit & Delete Actions
                                  AnimatedTapButton(
                                    scaleDown: 0.88,
                                    onTap: () => _showSubcategoryModalForm(initialSubcategory: Map<String, dynamic>.from(item)),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6.0),
                                      child: Icon(Icons.edit_outlined, size: 20, color: Colors.black),
                                    ),
                                  ),
                                  AnimatedTapButton(
                                    scaleDown: 0.88,
                                    onTap: () => _deleteSubcategory(id, name),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6.0),
                                      child: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                                    ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSubcategoryModalForm(),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Subcategory', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open_outlined, size: 60, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
