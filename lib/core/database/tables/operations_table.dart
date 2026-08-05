import 'package:drift/drift.dart';

@DataClassName('OperationRow')
class OperationsTable extends Table {
  @override
  String get tableName => 'operations';

  TextColumn get id => text()();
  TextColumn get userId => text()();

  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get externalId => text().nullable()();
  BoolColumn get isPending => boolean().withDefault(const Constant(false))();

  TextColumn get fromAccountId => text().nullable()();
  TextColumn get toAccountId => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get type => text()();
  RealColumn get amount => real()();
  TextColumn get currencyCode => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get recurrence => text()();
  BoolColumn get isRecurring => boolean()();
  TextColumn get note => text().nullable()();
  BoolColumn get categoryOverridden =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}
