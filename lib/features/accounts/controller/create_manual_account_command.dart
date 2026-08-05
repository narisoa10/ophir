import '../domain/enums/account_type.dart';

final class CreateManualAccountCommand {
  const CreateManualAccountCommand({
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.initialBalance,
  });

  final String name;
  final AccountType type;
  final String currencyCode;
  final double initialBalance;
}
