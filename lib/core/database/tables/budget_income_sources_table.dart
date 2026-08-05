import 'package:drift/drift.dart';

@DataClassName('BudgetIncomeSourceRow')
class BudgetIncomeSources extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get name => text()();
  TextColumn get categoryId => text()();
  RealColumn get amount => real()();
  TextColumn get frequency => text()();
  DateTimeColumn get nextPaymentDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}
