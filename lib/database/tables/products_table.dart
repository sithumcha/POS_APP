import 'package:drift/drift.dart';

@DataClassName('ProductEntity')
class ProductsTable extends Table {
  @override
  String get tableName => 'products';

  IntColumn get id => integer()();
  IntColumn get categoryId => integer().nullable().named('category_id')();
  IntColumn get subcategoryId => integer().nullable().named('subcategory_id')();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  RealColumn get price => real()();
  RealColumn get discountPrice => real().nullable().named('discount_price')();
  IntColumn get stock => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  BoolColumn get featured => boolean().withDefault(const Constant(false))();
  TextColumn get shortDescription => text().nullable().named('short_description')();
  TextColumn get fullDescription => text().nullable().named('full_description')();
  TextColumn get mainImage => text().nullable().named('main_image')();

  @override
  Set<Column> get primaryKey => {id};
}
