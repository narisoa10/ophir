import 'package:drift/drift.dart';

@DataClassName('BudgetObligationRow')
class BudgetObligations extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get categoryId => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get frequency => text()();
  DateTimeColumn get nextDueDate => dateTime().nullable()();
  TextColumn get obligationType => text()();
  TextColumn get name => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncStatus => text()();

  @override
  Set<Column> get primaryKey => {id};
}
