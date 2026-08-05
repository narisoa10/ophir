import '../../domain/entities/budget_household.dart';
import '../../domain/entities/budget_income_source.dart';
import '../../domain/entities/budget_obligation.dart';
import '../../domain/entities/budget_setup.dart';
import '../../domain/enums/budget_data_confidence.dart';
import '../../domain/enums/budget_data_source.dart';
import '../../domain/enums/budget_frequency.dart';
import '../dto/budget_income_source_dto.dart';
import '../dto/budget_obligation_dto.dart';
import '../dto/budget_setup_dto.dart';

final class BudgetPlanningMapper {
  const BudgetPlanningMapper._();

  static BudgetSetup toSetupDomain({
    required BudgetSetupDto dto,
    required List<BudgetIncomeSourceDto> incomeSources,
    required List<BudgetObligationDto> obligations,
  }) {
    return BudgetSetup(
      id: dto.id,
      userId: dto.userId,
      status: dto.status,
      version: dto.version,
      currentStep: dto.currentStep,
      household: BudgetHousehold(
        adultsCount: dto.adultsCount,
        childrenCount: dto.childrenCount,
        declaredCurrentBalance: dto.declaredCurrentBalance,
        reserveAmount: dto.reserveAmount,
        overdueAmount: dto.overdueAmount,
        upcomingLargeMandatoryAmount: dto.upcomingLargeMandatoryAmount,
        upcomingLargeMandatoryDate: dto.upcomingLargeMandatoryDate,
      ),
      incomeSources: incomeSources.map(toIncomeSourceDomain).toList(),
      obligations: obligations.map(toObligationDomain).toList(),
      completedAt: dto.completedAt,
      createdAt: dto.createdAt,
      updatedAt: dto.updatedAt,
    );
  }

  static BudgetIncomeSource toIncomeSourceDomain(BudgetIncomeSourceDto dto) {
    return BudgetIncomeSource(
      id: dto.id,
      setupId: dto.setupId,
      userId: dto.userId,
      name: dto.name,
      categoryId: dto.categoryId,
      amount: dto.amount,
      currencyCode: dto.currencyCode,
      frequency: _frequencyFromJson(dto.frequency),
      frequencyInterval: dto.frequencyInterval,
      timesPerYear: dto.timesPerYear,
      nextDate: dto.nextDate,
      source: _dataSourceFromJson(dto.source),
      confidence: _dataConfidenceFromJson(dto.confidence),
      isActive: dto.isActive,
    );
  }

  static BudgetObligation toObligationDomain(BudgetObligationDto dto) {
    return BudgetObligation(
      id: dto.id,
      setupId: dto.setupId,
      userId: dto.userId,
      categoryId: dto.categoryId,
      obligationType: dto.obligationType,
      amount: dto.amount,
      currencyCode: dto.currencyCode,
      frequency: _frequencyFromJson(dto.frequency),
      frequencyInterval: dto.frequencyInterval,
      timesPerYear: dto.timesPerYear,
      nextDueDate: dto.nextDueDate,
      minimumDebtPayment: dto.minimumDebtPayment,
      name: dto.name,
      isOverdue: dto.isOverdue,
      source: _dataSourceFromJson(dto.source),
      confidence: _dataConfidenceFromJson(dto.confidence),
      isActive: dto.isActive,
      note: dto.note,
    );
  }

  static BudgetSetupDto toSetupDto(BudgetSetup setup) {
    return BudgetSetupDto(
      id: setup.id,
      userId: setup.userId,
      status: setup.status,
      version: setup.version,
      currentStep: setup.currentStep,
      adultsCount: setup.household.adultsCount,
      childrenCount: setup.household.childrenCount,
      declaredCurrentBalance: setup.household.declaredCurrentBalance,
      reserveAmount: setup.household.reserveAmount,
      overdueAmount: setup.household.overdueAmount,
      upcomingLargeMandatoryAmount:
          setup.household.upcomingLargeMandatoryAmount,
      upcomingLargeMandatoryDate: setup.household.upcomingLargeMandatoryDate,
      completedAt: setup.completedAt,
      createdAt: setup.createdAt,
      updatedAt: setup.updatedAt,
    );
  }

  static BudgetIncomeSourceDto toIncomeSourceDto({
    required BudgetIncomeSource incomeSource,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return BudgetIncomeSourceDto(
      id: incomeSource.id,
      setupId: incomeSource.setupId,
      userId: incomeSource.userId,
      name: incomeSource.name,
      categoryId: incomeSource.categoryId,
      amount: incomeSource.amount,
      currencyCode: incomeSource.currencyCode,
      frequency: _frequencyToJson(incomeSource.frequency),
      frequencyInterval: incomeSource.frequencyInterval,
      timesPerYear: incomeSource.timesPerYear,
      nextDate: incomeSource.nextDate,
      source: _dataSourceToJson(incomeSource.source),
      confidence: _dataConfidenceToJson(incomeSource.confidence),
      isActive: incomeSource.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static BudgetObligationDto toObligationDto({
    required BudgetObligation obligation,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return BudgetObligationDto(
      id: obligation.id,
      setupId: obligation.setupId,
      userId: obligation.userId,
      categoryId: obligation.categoryId,
      obligationType: _obligationTypeToJson(obligation.obligationType),
      amount: obligation.amount,
      currencyCode: obligation.currencyCode,
      frequency: _frequencyToJson(obligation.frequency),
      frequencyInterval: obligation.frequencyInterval,
      timesPerYear: obligation.timesPerYear,
      nextDueDate: obligation.nextDueDate,
      minimumDebtPayment: obligation.minimumDebtPayment,
      name: obligation.name,
      isOverdue: obligation.isOverdue,
      source: _dataSourceToJson(obligation.source),
      confidence: _dataConfidenceToJson(obligation.confidence),
      isActive: obligation.isActive,
      note: obligation.note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static BudgetFrequency _frequencyFromJson(String value) {
    return switch (value) {
      'daily' => BudgetFrequency.daily,
      'weekly' => BudgetFrequency.weekly,
      'biweekly' => BudgetFrequency.biweekly,
      'semi_monthly' => BudgetFrequency.semiMonthly,
      'monthly' => BudgetFrequency.monthly,
      'every_n_months' => BudgetFrequency.everyNMonths,
      'times_per_year' => BudgetFrequency.timesPerYear,
      'yearly' => BudgetFrequency.yearly,
      'irregular' => BudgetFrequency.irregular,
      _ => throw ArgumentError.value(
        value,
        'value',
        'Invalid budget frequency',
      ),
    };
  }

  static String _frequencyToJson(BudgetFrequency value) {
    return switch (value) {
      BudgetFrequency.daily => 'daily',
      BudgetFrequency.weekly => 'weekly',
      BudgetFrequency.biweekly => 'biweekly',
      BudgetFrequency.semiMonthly => 'semi_monthly',
      BudgetFrequency.monthly => 'monthly',
      BudgetFrequency.everyNMonths => 'every_n_months',
      BudgetFrequency.timesPerYear => 'times_per_year',
      BudgetFrequency.yearly => 'yearly',
      BudgetFrequency.irregular => 'irregular',
    };
  }

  static String _obligationTypeToJson(String value) {
    return switch (value) {
      'living_expense' ||
      'debt_minimum' ||
      'yearly_expense' ||
      'urgent_expense' => value,
      _ when value.startsWith('expense.housing.') => 'living_expense',
      _ => value,
    };
  }

  static BudgetDataSource _dataSourceFromJson(String value) {
    return switch (value) {
      'declared' => BudgetDataSource.declared,
      'manual_operation' => BudgetDataSource.manualOperation,
      'bank_detected' => BudgetDataSource.bankDetected,
      'confirmed' => BudgetDataSource.confirmed,
      'system_calculated' => BudgetDataSource.systemCalculated,
      _ => throw ArgumentError.value(
        value,
        'value',
        'Invalid budget data source',
      ),
    };
  }

  static String _dataSourceToJson(BudgetDataSource value) {
    return switch (value) {
      BudgetDataSource.declared => 'declared',
      BudgetDataSource.manualOperation => 'manual_operation',
      BudgetDataSource.bankDetected => 'bank_detected',
      BudgetDataSource.confirmed => 'confirmed',
      BudgetDataSource.systemCalculated => 'system_calculated',
    };
  }

  static BudgetDataConfidence _dataConfidenceFromJson(String value) {
    return switch (value) {
      'estimated' => BudgetDataConfidence.estimated,
      'partially_observed' => BudgetDataConfidence.partiallyObserved,
      'verified' => BudgetDataConfidence.verified,
      _ => throw ArgumentError.value(
        value,
        'value',
        'Invalid budget data confidence',
      ),
    };
  }

  static String _dataConfidenceToJson(BudgetDataConfidence value) {
    return switch (value) {
      BudgetDataConfidence.estimated => 'estimated',
      BudgetDataConfidence.partiallyObserved => 'partially_observed',
      BudgetDataConfidence.verified => 'verified',
    };
  }
}
