import 'package:flutter/foundation.dart';

@immutable
final class BudgetSetupDto {
  const BudgetSetupDto({
    required this.id,
    required this.userId,
    required this.status,
    required this.version,
    required this.currentStep,
    required this.adultsCount,
    required this.childrenCount,
    required this.createdAt,
    required this.updatedAt,
    this.declaredCurrentBalance,
    this.reserveAmount,
    this.overdueAmount,
    this.upcomingLargeMandatoryAmount,
    this.upcomingLargeMandatoryDate,
    this.completedAt,
  });

  factory BudgetSetupDto.fromJson(Map<String, dynamic> json) {
    return BudgetSetupDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String,
      version: json['version'] as int,
      currentStep: json['current_step'] as int,
      adultsCount: json['adults_count'] as int,
      childrenCount: json['children_count'] as int,
      declaredCurrentBalance: json['declared_current_balance'] == null
          ? null
          : (json['declared_current_balance'] as num).toDouble(),
      reserveAmount: json['reserve_amount'] == null
          ? null
          : (json['reserve_amount'] as num).toDouble(),
      overdueAmount: json['overdue_amount'] == null
          ? null
          : (json['overdue_amount'] as num).toDouble(),
      upcomingLargeMandatoryAmount:
          json['upcoming_large_mandatory_amount'] == null
          ? null
          : (json['upcoming_large_mandatory_amount'] as num).toDouble(),
      upcomingLargeMandatoryDate: json['upcoming_large_mandatory_date'] == null
          ? null
          : DateTime.parse(json['upcoming_large_mandatory_date'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String status;
  final int version;
  final int currentStep;
  final int adultsCount;
  final int childrenCount;
  final double? declaredCurrentBalance;
  final double? reserveAmount;
  final double? overdueAmount;
  final double? upcomingLargeMandatoryAmount;
  final DateTime? upcomingLargeMandatoryDate;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'status': status,
      'version': version,
      'current_step': currentStep,
      'adults_count': adultsCount,
      'children_count': childrenCount,
      'declared_current_balance': declaredCurrentBalance,
      'reserve_amount': reserveAmount,
      'overdue_amount': overdueAmount,
      'upcoming_large_mandatory_amount': upcomingLargeMandatoryAmount,
      'upcoming_large_mandatory_date': upcomingLargeMandatoryDate
          ?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
