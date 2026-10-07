import 'package:drift/drift.dart';

@DataClassName('CategoryEntity')
class CategoriesTable extends Table {
  @override
  String get tableName => 'categories';

  IntColumn get id => integer()();
  IntColumn get userId => integer().nullable().named('user_id')();
  TextColumn get name => text()();
  TextColumn get slug => text().nullable()();
  TextColumn get image => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime().nullable().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().nullable().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}
