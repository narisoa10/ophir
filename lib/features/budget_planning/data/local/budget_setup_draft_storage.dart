import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/budget_setup_draft.dart';

final class BudgetSetupDraftStorage {
  const BudgetSetupDraftStorage();

  Future<void> saveDraft(BudgetSetupDraft draft) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(draft.userId), jsonEncode(draft.toJson()));
  }

  Future<BudgetSetupDraft?> loadDraft(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final jsonText = preferences.getString(_key(userId));

    if (jsonText == null) {
      return null;
    }

    return BudgetSetupDraft.fromJson(
      jsonDecode(jsonText) as Map<String, dynamic>,
    );
  }

  Future<void> clearDraft(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_key(userId));
  }

  String _key(String userId) {
    return 'budget_setup_draft_$userId';
  }
}
