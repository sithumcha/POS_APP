import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../services/api_service.dart';

class CatalogSyncRepository {
  final ApiService _apiService;
  final AppDatabase _db;

  CatalogSyncRepository({
    required ApiService apiService,
    required AppDatabase db,
  })  : _apiService = apiService,
        _db = db;

  /// Syncs remote API catalog (Categories, Subcategories, Products) into local Drift DB.
  /// Returns [true] if sync succeeded, or [false] if offline/failed without crashing.
  Future<bool> syncFullCatalog() async {
    try {
      // 1. Fetch from Remote API
      final rawCategories = await _apiService.getCategories();
      final rawSubcategories = await _apiService.getSubcategories();
      final rawProducts = await _apiService.getProducts();

      // 2. Map Categories to Drift Companions
      final categoryCompanions = rawCategories.map((raw) {
        final map = raw as Map<String, dynamic>;
        final createdAtStr = map['created_at']?.toString();
        final updatedAtStr = map['updated_at']?.toString();

        return CategoriesTableCompanion(
          id: Value(map['id'] as int),
          userId: Value(map['user_id'] as int?),
          name: Value(map['name']?.toString() ?? ''),
          slug: Value(map['slug']?.toString()),
          image: Value(map['image']?.toString()),
          description: Value(map['description']?.toString()),
          status: Value(map['status']?.toString() ?? 'active'),
          createdAt: Value(createdAtStr != null ? DateTime.tryParse(createdAtStr) : null),
          updatedAt: Value(updatedAtStr != null ? DateTime.tryParse(updatedAtStr) : null),
        );
      }).toList();

      // 3. Map Subcategories to Drift Companions
      final subcategoryCompanions = rawSubcategories.map((raw) {
        final map = raw as Map<String, dynamic>;

        return SubcategoriesTableCompanion(
          id: Value(map['id'] as int),
          categoryId: Value(map['category_id'] as int),
          name: Value(map['name']?.toString() ?? ''),
          slug: Value(map['slug']?.toString()),
          image: Value(map['image']?.toString()),
          description: Value(map['description']?.toString()),
          status: Value(map['status']?.toString() ?? 'active'),
        );
      }).toList();

      // 4. Map Products to Drift Companions
      final productCompanions = rawProducts.map((raw) {
        final map = raw as Map<String, dynamic>;

        return ProductsTableCompanion(
          id: Value(map['id'] as int),
          categoryId: Value(map['category_id'] as int?),
          subcategoryId: Value(map['subcategory_id'] as int?),
          name: Value(map['name']?.toString() ?? ''),
          sku: Value(map['sku']?.toString()),
          price: Value((map['price'] is num)
              ? (map['price'] as num).toDouble()
              : double.tryParse(map['price']?.toString() ?? '0') ?? 0.0),
          discountPrice: Value(map['discount_price'] != null
              ? ((map['discount_price'] is num)
                  ? (map['discount_price'] as num).toDouble()
                  : double.tryParse(map['discount_price']?.toString() ?? ''))
              : null),
          stock: Value((map['stock'] is int)
              ? (map['stock'] as int)
              : int.tryParse(map['stock']?.toString() ?? '0') ?? 0),
          status: Value(map['status']?.toString() ?? 'active'),
          featured: Value(map['featured'] == true || map['featured'] == 1),
          shortDescription: Value(map['short_description']?.toString()),
          fullDescription: Value(map['full_description']?.toString()),
          mainImage: Value(map['main_image']?.toString()),
        );
      }).toList();

      // 5. Batch Upsert to Local Database
      if (categoryCompanions.isNotEmpty) {
        await _db.batchUpsertCategories(categoryCompanions);
      }
      if (subcategoryCompanions.isNotEmpty) {
        await _db.batchUpsertSubcategories(subcategoryCompanions);
      }
      if (productCompanions.isNotEmpty) {
        await _db.batchUpsertProducts(productCompanions);
      }

      return true;
    } catch (e) {
      // Offline mode or network error - return false safely without unhandled exception
      return false;
    }
  }

  Future<List<dynamic>> getCachedOrRemoteCategories() async {
    try {
      final remote = await _apiService.getCategories();
      if (remote.isNotEmpty) return remote;
    } catch (_) {}
    return await _apiService.getCategories();
  }

  Future<List<dynamic>> getCachedOrRemoteProducts() async {
    try {
      final remote = await _apiService.getProducts();
      if (remote.isNotEmpty) return remote;
    } catch (_) {}
    return await _apiService.getProducts();
  }
}
