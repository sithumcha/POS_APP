import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables/categories_table.dart';
import 'tables/subcategories_table.dart';
import 'tables/products_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [CategoriesTable, SubcategoriesTable, ProductsTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      : super(
          driftDatabase(
            name: 'pos_local_db',
            web: DriftWebOptions(
              sqlite3Wasm: Uri.parse('sqlite3.wasm'),
              driftWorker: Uri.parse('drift_worker.js'),
            ),
          ),
        );

  @override
  int get schemaVersion => 1;

  // --- Batch Upsert Methods ---

  Future<void> batchUpsertCategories(List<CategoriesTableCompanion> companions) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(categoriesTable, companions);
    });
  }

  Future<void> batchUpsertSubcategories(List<SubcategoriesTableCompanion> companions) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(subcategoriesTable, companions);
    });
  }

  Future<void> batchUpsertProducts(List<ProductsTableCompanion> companions) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(productsTable, companions);
    });
  }

  // --- Reactive Stream Methods ---

  Stream<List<CategoryEntity>> watchAllCategories() {
    return (select(categoriesTable)
          ..where((tbl) => tbl.status.equals('active')))
        .watch();
  }

  Stream<List<SubcategoryEntity>> watchSubcategoriesByParent(int categoryId) {
    return (select(subcategoriesTable)
          ..where((tbl) => tbl.categoryId.equals(categoryId) & tbl.status.equals('active')))
        .watch();
  }

  Stream<List<ProductEntity>> watchProducts({
    int? categoryId,
    int? subcategoryId,
    String? searchQuery,
  }) {
    final query = select(productsTable);

    query.where((tbl) {
      Expression<bool> predicate = tbl.status.equals('active');

      if (categoryId != null) {
        predicate = predicate & tbl.categoryId.equals(categoryId);
      }

      if (subcategoryId != null) {
        predicate = predicate & tbl.subcategoryId.equals(subcategoryId);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = '%${searchQuery.trim().toLowerCase()}%';
        predicate = predicate & (tbl.name.lower().like(q) | tbl.sku.lower().like(q));
      }

      return predicate;
    });

    return query.watch();
  }

  Future<int> updateProductStock(int productId, int newStock) {
    return (update(productsTable)..where((tbl) => tbl.id.equals(productId))).write(
      ProductsTableCompanion(stock: Value(newStock)),
    );
  }
}
