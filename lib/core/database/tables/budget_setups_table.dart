import 'package:drift/drift.dart';

@DataClassName('BudgetSetupRow')
class BudgetSetups extends Table {
  TextColumn get userId => text()();
  IntColumn get currentStep => integer()();
  IntColumn get adults => integer()();
  IntColumn get children => integer()();
  TextColumn get currencyCode => text()();
  BoolColumn get isCompleted => boolean()();
  TextColumn get syncStatus => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId};
}
