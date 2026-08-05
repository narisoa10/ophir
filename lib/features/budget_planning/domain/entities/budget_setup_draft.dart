import 'package:flutter/foundation.dart';

import '../enums/budget_data_confidence.dart';
import '../enums/budget_data_source.dart';
import '../enums/budget_frequency.dart';
import 'budget_household.dart';
import 'budget_income_source.dart';
import 'budget_obligation.dart';

@immutable
final class BudgetSetupDraft {
  const BudgetSetupDraft({
    required this.userId,
    required this.currencyCode,
    required this.currentStep,
    required this.household,
    required this.incomeSources,
    required this.obligations,
    required this.version,
  });

  factory BudgetSetupDraft.fromJson(Map<String, dynamic> json) {
    return BudgetSetupDraft(
      userId: json['userId'] as String,
      currencyCode: json['currencyCode'] as String? ?? '',
      currentStep: json['currentStep'] as int,
      household: _householdFromJson(json['household'] as Map<String, dynamic>),
      incomeSources: ((json['incomeSources'] as List<dynamic>?) ?? const [])
          .map((item) => _incomeSourceFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      obligations: ((json['obligations'] as List<dynamic>?) ?? const [])
          .map((item) => _obligationFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      version: json['version'] as int,
    );
  }

  final String userId;
  final String currencyCode;
  final int currentStep;
  final BudgetHousehold household;
  final List<BudgetIncomeSource> incomeSources;
  final List<BudgetObligation> obligations;
  final int version;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'currencyCode': currencyCode,
      'currentStep': currentStep,
      'household': _householdToJson(household),
      'incomeSources': incomeSources.map(_incomeSourceToJson).toList(),
      'obligations': obligations.map(_obligationToJson).toList(),
      'version': version,
    };
  }

  static BudgetHousehold _householdFromJson(Map<String, dynamic> json) {
    return BudgetHousehold(
      adultsCount: json['adultsCount'] as int,
      childrenCount: json['childrenCount'] as int,
    );
  }

  static Map<String, dynamic> _householdToJson(BudgetHousehold household) {
    return {
      'adultsCount': household.adultsCount,
      'childrenCount': household.childrenCount,
    };
  }

  static BudgetIncomeSource _incomeSourceFromJson(Map<String, dynamic> json) {
    return BudgetIncomeSource(
      id: json['id'] as String,
      setupId: '',
      userId: '',
      name: json['name'] as String? ?? '',
      categoryId: json['categoryId'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currencyCode'] as String,
      frequency: _enumValue(
        BudgetFrequency.values,
        json['frequency'] as String,
      ),
      frequencyInterval: json['frequencyInterval'] as int?,
      timesPerYear: json['timesPerYear'] as int?,
      nextDate: json['nextDate'] == null
          ? null
          : DateTime.parse(json['nextDate'] as String),
      source: _enumValue(BudgetDataSource.values, json['source'] as String),
      confidence: _enumValue(
        BudgetDataConfidence.values,
        json['confidence'] as String,
      ),
      isActive: json['isActive'] as bool,
    );
  }

  static Map<String, dynamic> _incomeSourceToJson(
    BudgetIncomeSource incomeSource,
  ) {
    return {
      'id': incomeSource.id,
      'name': incomeSource.name,
      'categoryId': incomeSource.categoryId,
      'amount': incomeSource.amount,
      'currencyCode': incomeSource.currencyCode,
      'frequency': incomeSource.frequency.name,
      'frequencyInterval': incomeSource.frequencyInterval,
      'timesPerYear': incomeSource.timesPerYear,
      'nextDate': incomeSource.nextDate?.toIso8601String(),
      'source': incomeSource.source.name,
      'confidence': incomeSource.confidence.name,
      'isActive': incomeSource.isActive,
    };
  }

  static BudgetObligation _obligationFromJson(Map<String, dynamic> json) {
    return BudgetObligation(
      id: json['id'] as String,
      setupId: json['setupId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      categoryId: json['categoryId'] as String?,
      obligationType: json['obligationType'] as String,
      amount: (json['amount'] as num).toDouble(),
      currencyCode: json['currencyCode'] as String,
      frequency: _enumValue(
        BudgetFrequency.values,
        json['frequency'] as String,
      ),
      frequencyInterval: json['frequencyInterval'] as int?,
      timesPerYear: json['timesPerYear'] as int?,
      nextDueDate: json['nextDueDate'] == null
          ? null
          : DateTime.parse(json['nextDueDate'] as String),
      minimumDebtPayment: json['minimumDebtPayment'] == null
          ? null
          : (json['minimumDebtPayment'] as num).toDouble(),
      name: json['name'] as String?,
      isOverdue: json['isOverdue'] as bool,
      source: _enumValue(BudgetDataSource.values, json['source'] as String),
      confidence: _enumValue(
        BudgetDataConfidence.values,
        json['confidence'] as String,
      ),
      isActive: json['isActive'] as bool,
      note: json['note'] as String?,
    );
  }

  static Map<String, dynamic> _obligationToJson(BudgetObligation obligation) {
    return {
      'id': obligation.id,
      'setupId': obligation.setupId,
      'userId': obligation.userId,
      'categoryId': obligation.categoryId,
      'obligationType': obligation.obligationType,
      'amount': obligation.amount,
      'currencyCode': obligation.currencyCode,
      'frequency': obligation.frequency.name,
      'frequencyInterval': obligation.frequencyInterval,
      'timesPerYear': obligation.timesPerYear,
      'nextDueDate': obligation.nextDueDate?.toIso8601String(),
      'minimumDebtPayment': obligation.minimumDebtPayment,
      'name': obligation.name,
      'isOverdue': obligation.isOverdue,
      'source': obligation.source.name,
      'confidence': obligation.confidence.name,
      'isActive': obligation.isActive,
      'note': obligation.note,
    };
  }

  static T _enumValue<T extends Enum>(List<T> values, String name) {
    return values.firstWhere((value) => value.name == name);
  }
}
