import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/budget_household.dart';
import '../../domain/entities/budget_income_source.dart';
import '../../domain/entities/budget_obligation.dart';
import '../../domain/entities/budget_setup.dart';
import '../../domain/repositories/budget_planning_repository.dart';
import '../dto/budget_income_source_dto.dart';
import '../dto/budget_obligation_dto.dart';
import '../dto/budget_setup_dto.dart';
import '../mappers/budget_planning_mapper.dart';

final class SupabaseBudgetPlanningRepository
    implements BudgetPlanningRepository {
  SupabaseBudgetPlanningRepository(this._client);

  final SupabaseClient _client;

  static const _setupTable = 'budget_setups';
  static const _incomeSourceTable = 'budget_income_sources';
  static const _obligationTable = 'budget_obligations';

  @override
  Future<BudgetSetup?> getCurrentSetup() async {
    final user = _requireUser();

    final data = await _client
        .from(_setupTable)
        .select()
        .eq('user_id', user.id)
        .limit(1)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return _mapSetupRow(data);
  }

  @override
  Stream<BudgetSetup?> watchCurrentSetup() {
    final user = _client.auth.currentUser;

    if (user == null) {
      return Stream.error(StateError('Current user is required.'));
    }

    return _client
        .from(_setupTable)
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .asyncMap((rows) async {
          if (rows.isEmpty) {
            return null;
          }

          return _mapSetupRow(rows.first);
        });
  }

  @override
  Future<BudgetSetup> createSetup({required BudgetHousehold household}) async {
    final currentSetup = await getCurrentSetup();

    if (currentSetup != null) {
      return currentSetup;
    }

    final user = _requireUser();

    final data = await _client
        .from(_setupTable)
        .insert({
          'user_id': user.id,
          'status': 'draft',
          'version': 1,
          'current_step': 0,
          'adults_count': household.adultsCount,
          'children_count': household.childrenCount,
          'declared_current_balance': household.declaredCurrentBalance,
          'reserve_amount': household.reserveAmount,
          'overdue_amount': household.overdueAmount,
          'upcoming_large_mandatory_amount':
              household.upcomingLargeMandatoryAmount,
          'upcoming_large_mandatory_date': household.upcomingLargeMandatoryDate
              ?.toIso8601String(),
        })
        .select()
        .single();

    return BudgetPlanningMapper.toSetupDomain(
      dto: BudgetSetupDto.fromJson(data),
      incomeSources: const [],
      obligations: const [],
    );
  }

  @override
  Future<BudgetSetup> saveSetup(BudgetSetup setup) async {
    final user = _requireUser();

    await _client
        .from(_setupTable)
        .update({
          'status': setup.status,
          'version': setup.version,
          'current_step': setup.currentStep,
          'adults_count': setup.household.adultsCount,
          'children_count': setup.household.childrenCount,
          'declared_current_balance': setup.household.declaredCurrentBalance,
          'reserve_amount': setup.household.reserveAmount,
          'overdue_amount': setup.household.overdueAmount,
          'upcoming_large_mandatory_amount':
              setup.household.upcomingLargeMandatoryAmount,
          'upcoming_large_mandatory_date': setup
              .household
              .upcomingLargeMandatoryDate
              ?.toIso8601String(),
          'completed_at': setup.completedAt?.toIso8601String(),
        })
        .eq('id', setup.id)
        .eq('user_id', user.id);

    await replaceIncomeSources(
      setupId: setup.id,
      incomeSources: setup.incomeSources,
    );
    await replaceObligations(setupId: setup.id, obligations: setup.obligations);

    final currentSetup = await _getSetupById(setup.id);

    if (currentSetup == null) {
      throw StateError('Budget setup was not found after saving.');
    }

    return currentSetup;
  }

  @override
  Future<void> replaceIncomeSources({
    required String setupId,
    required List<BudgetIncomeSource> incomeSources,
  }) async {
    final user = _requireUser();

    await _client
        .from(_incomeSourceTable)
        .delete()
        .eq('setup_id', setupId)
        .eq('user_id', user.id);

    if (incomeSources.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    final rows = incomeSources
        .map((incomeSource) {
          final dto = BudgetPlanningMapper.toIncomeSourceDto(
            incomeSource: BudgetIncomeSource(
              id: incomeSource.id,
              setupId: setupId,
              userId: user.id,
              name: incomeSource.name,
              categoryId: incomeSource.categoryId,
              amount: incomeSource.amount,
              currencyCode: incomeSource.currencyCode,
              frequency: incomeSource.frequency,
              frequencyInterval: incomeSource.frequencyInterval,
              timesPerYear: incomeSource.timesPerYear,
              nextDate: incomeSource.nextDate,
              source: incomeSource.source,
              confidence: incomeSource.confidence,
              isActive: incomeSource.isActive,
            ),
            createdAt: now,
            updatedAt: now,
          );

          return dto.toJson();
        })
        .toList(growable: false);

    await _client.from(_incomeSourceTable).insert(rows);
  }

  @override
  Future<void> replaceObligations({
    required String setupId,
    required List<BudgetObligation> obligations,
  }) async {
    final user = _requireUser();

    await _client
        .from(_obligationTable)
        .delete()
        .eq('setup_id', setupId)
        .eq('user_id', user.id);

    if (obligations.isEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    final rows = obligations
        .map((obligation) {
          final dto = BudgetPlanningMapper.toObligationDto(
            obligation: BudgetObligation(
              id: obligation.id,
              setupId: setupId,
              userId: user.id,
              categoryId: obligation.categoryId,
              obligationType: obligation.obligationType,
              amount: obligation.amount,
              currencyCode: obligation.currencyCode,
              frequency: obligation.frequency,
              frequencyInterval: obligation.frequencyInterval,
              timesPerYear: obligation.timesPerYear,
              nextDueDate: obligation.nextDueDate,
              minimumDebtPayment: obligation.minimumDebtPayment,
              name: obligation.name,
              isOverdue: obligation.isOverdue,
              source: obligation.source,
              confidence: obligation.confidence,
              isActive: obligation.isActive,
              note: obligation.note,
            ),
            createdAt: now,
            updatedAt: now,
          );

          return dto.toJson();
        })
        .toList(growable: false);

    await _client.from(_obligationTable).insert(rows);
  }

  @override
  Future<BudgetSetup> completeSetup(String setupId) async {
    final user = _requireUser();

    await _client
        .from(_setupTable)
        .update({
          'status': 'completed',
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', setupId)
        .eq('user_id', user.id);

    final currentSetup = await _getSetupById(setupId);

    if (currentSetup == null) {
      throw StateError('Budget setup was not found after completion.');
    }

    return currentSetup;
  }

  @override
  Future<void> deleteSetup(String setupId) async {
    final user = _requireUser();

    await _client
        .from(_setupTable)
        .delete()
        .eq('id', setupId)
        .eq('user_id', user.id);
  }

  User _requireUser() {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('Current user is required.');
    }

    return user;
  }

  Future<List<BudgetIncomeSourceDto>> _loadIncomeSources(String setupId) async {
    final data = await _client
        .from(_incomeSourceTable)
        .select()
        .eq('setup_id', setupId);

    return data
        .map((json) => BudgetIncomeSourceDto.fromJson(json))
        .toList(growable: false);
  }

  Future<List<BudgetObligationDto>> _loadObligations(String setupId) async {
    final data = await _client
        .from(_obligationTable)
        .select()
        .eq('setup_id', setupId);

    return data
        .map((json) => BudgetObligationDto.fromJson(json))
        .toList(growable: false);
  }

  Future<BudgetSetup> _mapSetupRow(Map<String, dynamic> row) async {
    final setupDto = BudgetSetupDto.fromJson(row);
    final incomeSources = await _loadIncomeSources(setupDto.id);
    final obligations = await _loadObligations(setupDto.id);

    return BudgetPlanningMapper.toSetupDomain(
      dto: setupDto,
      incomeSources: incomeSources,
      obligations: obligations,
    );
  }

  Future<BudgetSetup?> _getSetupById(String setupId) async {
    final user = _requireUser();

    final data = await _client
        .from(_setupTable)
        .select()
        .eq('id', setupId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (data == null) {
      return null;
    }

    return _mapSetupRow(data);
  }
}
