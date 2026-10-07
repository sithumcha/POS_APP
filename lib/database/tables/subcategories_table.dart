import 'package:drift/drift.dart';

@DataClassName('SubcategoryEntity')
class SubcategoriesTable extends Table {
  @override
  String get tableName => 'subcategories';

  IntColumn get id => integer()();
  IntColumn get categoryId => integer().named('category_id')();
  TextColumn get name => text()();
  TextColumn get slug => text().nullable()();
  TextColumn get image => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();

  @override
  Set<Column> get primaryKey => {id};
}
