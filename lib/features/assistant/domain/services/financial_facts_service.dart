import '../../../accounts/domain/entities/account.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/domain/enums/category_analytics_group.dart';
import '../../../operations/domain/entities/operation.dart';
import '../../../operations/domain/enums/operation_recurrence.dart';
import '../../../operations/domain/enums/operation_type.dart';
import '../entities/financial_fact.dart';
import '../entities/financial_fact_confidence.dart';
import '../entities/financial_fact_data_gap.dart';
import '../entities/financial_fact_data_gap_type.dart';
import '../entities/financial_fact_source.dart';
import '../entities/financial_fact_type.dart';
import '../entities/financial_facts_snapshot.dart';

final class FinancialFactsService {
  const FinancialFactsService();

  FinancialFactsSnapshot buildSnapshot({
    required List<Operation> operations,
    required List<Category> categories,
    List<Account>? accounts,
  }) {
    final facts = <FinancialFact>[];
    final dataGaps = <FinancialFactDataGap>[];
    final categoryById = {
      for (final category in categories)
        if (_isUsableCategory(category)) category.id: category,
    };
    final accountById = {
      for (final account in accounts ?? const <Account>[])
        if (!account.isArchived) account.id: account,
    };

    for (final account in accountById.values) {
      facts.add(_accountBalanceSeedFact(account));
    }

    for (final operation in operations) {
      facts.add(_operationTypeFact(operation));

      if (_isRecurring(operation)) {
        facts.add(_recurringFact(operation));
      }

      final categoryId = operation.categoryId;
      if (categoryId == null) {
        facts.add(_uncategorizedFact(operation));
        dataGaps.add(_missingCategoryGap(operation));
      } else {
        final category = categoryById[categoryId];
        if (category == null) {
          facts.add(_uncategorizedFact(operation));
          dataGaps.add(_missingCategoryGap(operation));
        } else {
          facts.add(_categorizedFact(operation, category.id));
          facts.add(_analyticsGroupFact(operation, category));
        }
      }

      final linkedAccountId = _linkedAccountId(operation);
      if (linkedAccountId == null) {
        facts.add(_unlinkedFact(operation));
        dataGaps.add(_missingAccountLinkGap(operation));
      } else {
        facts.add(_accountLinkedFact(operation, linkedAccountId));

        if (accounts != null && !accountById.containsKey(linkedAccountId)) {
          dataGaps.add(_missingAccountDataGap(operation, linkedAccountId));
        }
      }
    }

    return FinancialFactsSnapshot(
      facts: List.unmodifiable(facts),
      dataGaps: List.unmodifiable(dataGaps),
    );
  }

  FinancialFact _operationTypeFact(Operation operation) {
    return _operationFact(
      operation: operation,
      type: switch (operation.type) {
        OperationType.income => FinancialFactType.incomeOperation,
        OperationType.expense => FinancialFactType.expenseOperation,
        OperationType.transfer => FinancialFactType.transferOperation,
      },
    );
  }

  FinancialFact _recurringFact(Operation operation) {
    return _operationFact(
      operation: operation,
      type: FinancialFactType.recurringOperation,
    );
  }

  FinancialFact _categorizedFact(Operation operation, String categoryId) {
    return _operationFact(
      operation: operation,
      type: FinancialFactType.categorizedOperation,
      categoryId: categoryId,
    );
  }

  FinancialFact _uncategorizedFact(Operation operation) {
    return _operationFact(
      operation: operation,
      type: FinancialFactType.uncategorizedOperation,
      confidence: FinancialFactConfidence.medium,
    );
  }

  FinancialFact _analyticsGroupFact(Operation operation, Category category) {
    return _operationFact(
      operation: operation,
      type: FinancialFactType.analyticsGroup,
      source: FinancialFactSource.category,
      categoryId: category.id,
      analyticsGroup: category.analyticsGroup,
    );
  }

  FinancialFact _accountLinkedFact(Operation operation, String accountId) {
    return _operationFact(
      operation: operation,
      type: FinancialFactType.accountLinked,
      accountId: accountId,
    );
  }

  FinancialFact _unlinkedFact(Operation operation) {
    return _operationFact(
      operation: operation,
      type: FinancialFactType.unlinked,
      confidence: FinancialFactConfidence.medium,
    );
  }

  FinancialFact _accountBalanceSeedFact(Account account) {
    return FinancialFact(
      id: 'account:${account.id}:balance_seed',
      type: FinancialFactType.accountBalanceSeed,
      source: FinancialFactSource.account,
      confidence: FinancialFactConfidence.high,
      accountId: account.id,
      userId: account.userId,
      amount: account.initialBalance,
      currencyCode: account.currencyCode,
    );
  }

  FinancialFact _operationFact({
    required Operation operation,
    required FinancialFactType type,
    FinancialFactSource source = FinancialFactSource.manualRecorded,
    FinancialFactConfidence confidence = FinancialFactConfidence.high,
    String? categoryId,
    String? accountId,
    CategoryAnalyticsGroup? analyticsGroup,
  }) {
    return FinancialFact(
      id: 'operation:${operation.id}:${type.name}',
      type: type,
      source: source,
      confidence: confidence,
      operationId: operation.id,
      categoryId: categoryId ?? operation.categoryId,
      accountId: accountId,
      userId: operation.userId,
      operationType: operation.type,
      amount: operation.amount,
      currencyCode: operation.currencyCode,
      occurredAt: operation.occurredAt,
      recurrence: operation.recurrence,
      analyticsGroup: analyticsGroup,
    );
  }

  FinancialFactDataGap _missingCategoryGap(Operation operation) {
    return FinancialFactDataGap(
      type: FinancialFactDataGapType.missingCategory,
      sourceId: operation.id,
      message: 'Operation has no active category fact.',
    );
  }

  FinancialFactDataGap _missingAccountLinkGap(Operation operation) {
    return FinancialFactDataGap(
      type: FinancialFactDataGapType.missingAccountLink,
      sourceId: operation.id,
      message: 'Operation is not linked to an account.',
    );
  }

  FinancialFactDataGap _missingAccountDataGap(
    Operation operation,
    String accountId,
  ) {
    return FinancialFactDataGap(
      type: FinancialFactDataGapType.missingAccountData,
      sourceId: operation.id,
      message: 'Operation references unavailable account $accountId.',
    );
  }

  bool _isRecurring(Operation operation) {
    return operation.isRecurring ||
        operation.recurrence != OperationRecurrence.none;
  }

  bool _isUsableCategory(Category category) {
    return category.isActive || category.stableKey != null;
  }

  String? _linkedAccountId(Operation operation) {
    return switch (operation.type) {
      OperationType.expense => operation.fromAccountId,
      OperationType.income => operation.toAccountId,
      OperationType.transfer =>
        operation.fromAccountId ?? operation.toAccountId,
    };
  }
}
