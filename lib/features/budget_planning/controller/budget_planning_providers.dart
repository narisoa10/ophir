import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/budget_setup_draft_storage.dart';
import '../data/repositories/supabase_budget_planning_repository.dart';
import '../domain/repositories/budget_planning_repository.dart';

final supabaseBudgetPlanningRepositoryProvider =
    Provider<BudgetPlanningRepository>((ref) {
      return SupabaseBudgetPlanningRepository(Supabase.instance.client);
    });

final budgetSetupDraftStorageProvider = Provider<BudgetSetupDraftStorage>((
  ref,
) {
  return const BudgetSetupDraftStorage();
});
