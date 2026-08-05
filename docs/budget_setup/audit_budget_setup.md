Надо сохранить их в Docs                                                                                                                                    1. Какие существующие файлы можно переиспользовать

- Profile/settings: lib/features/profile/domain/entities/profile.dart:4, lib/features/profile/data/dto/profile_dto.dart:1, lib/features/profile/data/repositories/
  supabase_profile_repository.dart:20, lib/features/profile/controller/profile_controller.dart:7, lib/features/profile/controller/profile_providers.dart:9.

- Routing shell: lib/app/router/app_router.dart:25, lib/app/router/app_routes.dart:1.
- Operations CRUD/form widgets: lib/features/operations/domain/entities/operation.dart:7, lib/features/operations/data/dto/operation_dto.dart:1, lib/features/
  operations/controller/operation_controller.dart:8, lib/features/operations/presentation/screens/create_operation_screen.dart:39, lib/features/operations/
  presentation/widgets/operation_text_field.dart:4, lib/features/operations/presentation/widgets/operation_type_toggle.dart:6.

- Category taxonomy/picker: lib/features/categories/domain/enums/category_stable_key.dart:1, lib/features/categories/domain/entities/category_taxonomy.dart:7, lib/
  features/categories/domain/services/category_financial_behavior_policy.dart:7, lib/features/categories/controller/category_picker_taxonomy_providers.dart:11, lib/
  features/operations/presentation/screens/operation_category_picker_screen.dart:15.

- Accounts/current balance base: lib/features/accounts/domain/entities/account.dart:6, lib/features/accounts/data/dto/account_dto.dart:1, lib/features/accounts/data/
  repositories/supabase_account_repository.dart:10, lib/features/accounts/presentation/screens/create_account_screen.dart:26.

- Theme/localization: lib/core/theme_v1/*, lib/core/localization/l10n/app_en.arb:114.

2. Какие existing entities/fields уже покрывают вопросы

- Profile: fullName, locale, currencyCode, timezone, onboardingCompleted есть в entity/DTO и Supabase: lib/features/profile/domain/entities/profile.dart:18, lib/
  features/profile/data/dto/profile_dto.dart:30, supabase/migrations/20260629150520_create_profiles.sql:8.

- adult_count, children_count, household composition, financial user settings отсутствуют.
- Operation: type, amount, currencyCode, categoryId, occurredAt, recurrence, isRecurring, note, fromAccountId/toAccountId есть: lib/features/operations/domain/
  entities/operation.dart:25, lib/features/operations/data/dto/operation_dto.dart:34.

- Operation не имеет source, status, nextDueDate, nextOccurrence, planned/future flag, description отдельно от note.
- Account: type, currencyCode, initialBalance, archive flag есть: lib/features/accounts/domain/entities/account.dart:22.
- Category: stableKey, type, groups, active flag есть: lib/features/categories/domain/entities/category.dart:25.

3. Какие вопросы уже поддерживаются текущей моделью без изменений

- Доход: тип через income category, чистая сумма через Operation.amount, дата через occurredAt, частота через OperationRecurrence.
- Поддержанные частоты: daily, weekly, biweekly, monthly, yearly, none: lib/features/operations/domain/enums/operation_recurrence.dart:1, Supabase check: supabase/
  migrations/20260630225522_add_operation_recurrence.sql:5.

- Weekly, biweekly, monthly, yearly поддержаны. Irregular можно приблизительно хранить как none, но без явной семантики irregular.
- Semi-monthly, every N months, N times per year не поддержаны.
- Обязательные категории уже есть для жилья, коммунальных, продуктов, гигиены, лекарств, транспорта, детей/иждивенцев, питомцев, долгов, годовых гос./налоговых
  платежей: lib/features/categories/domain/services/category_financial_behavior_policy.dart:117, supabase/
  migrations/20260707121000_seed_missing_category_taxonomy_rows.sql:13.

- Текущий доступный баланс можно сохранить только как Account.initialBalance, не как отдельный questionnaire answer.

4. Какие вопросы требуют новых полей

- Household: количество взрослых, детей, состав домохозяйства.
- Income: nextDate как плановая следующая дата, fixed/variable, primary/secondary, semi-monthly/every N months/N times per year/irregular enum, salary-specific
  metadata.

- Mandatory expenses: due date/next occurrence, planned status, quarterly/every N months recurrence, debt details, regular medication details, yearly/rare obligation
  metadata.

- Reserve/urgent: current reserve, overdue payments, nearest large mandatory spend.
- Onboarding/questionnaire: draft/save-resume state, completion state per step, versioning/source of answers.

5. Какие Supabase migrations понадобятся

- Новая таблица для стартового бюджетного плана нужна. Текущие operations являются фактами и не должны становиться хранилищем questionnaire plan.
- Минимально нужны migration для budget setup header + line items: household answers, income sources, mandatory expense obligations, reserve/urgent obligations.
- Нужны поля/таблица для recurrence details beyond enum: semi-monthly, every N months, N times/year, irregular.
- Нужна связь с profiles.id, RLS own-user policies, timestamps, draft/completed status.
- Можно оставить profiles.onboarding_completed, но для финансового опроса нужен отдельный completion/progress marker, иначе нельзя save/resume по шагам.

6. Какие новые production-файлы действительно будут нужны

- features/budget_setup/domain: entities для plan, household, income source, obligation, reserve/urgent item, recurrence/frequency enum.
- features/budget_setup/data: DTO/mappers/Supabase repository.
- features/budget_setup/controller: questionnaire state/controller/providers.
- features/budget_setup/presentation: screens/step widgets/progress UI.
- Routing additions in lib/app/router/app_routes.dart:1 and lib/app/router/app_router.dart:25.
- Localization keys for questionnaire-specific copy are missing; existing category/frequency labels can be reused, but household/reserve/overdue/setup text needs new
  keys.

7. В каком порядке внедрить опрос
8. Screens: создать questionnaire screens, переиспользовать Theme_V1, OperationTextField, category taxonomy picker pattern, recurrence picker pattern.
9. Persistence: добавить Supabase migrations + repository/controller для draft/save/resume.
10. Calculation: отдельно считать стартовый budget plan из questionnaire data, не из factual operations.
11. Routing/onboarding: добавить routes, redirect/gate по отдельному budget setup completion и только после сохранения помечать profile onboarding/financial setup
    completed.

12. Какие части нельзя смешивать с фактическими operations

- Planned income/expense sources, next due dates, unpaid/overdue payments, reserve, nearest large mandatory spend.
- Draft questionnaire answers.
- Recurring schedule definitions.
- Debt/medication/housing obligation metadata.
- operations.occurredAt сейчас означает дату операции; использовать его как “следующая дата платежа” нельзя без смешивания плана и факта.

9. Что уже готово для следующего этапа банковской интеграции

- Есть accounts table/entity/repository/controller, тип bank, initial_balance, account CRUD и UI создания: supabase/migrations/20260630161853_create_accounts.sql:1,
  lib/features/accounts/domain/enums/account_type.dart:1.

- Есть операции с from_account_id/to_account_id, что подходит для будущего transaction import mapping: supabase/
  migrations/20260630171029_update_operations_transfer_fields.sql:1.

- Не готово: linked bank provider, external account identifiers, institution table, imported transaction table, sync status, deduplication/import source. Сейчас есть
  только общие placeholders в Settings Data для import/export, без банковской интеграции.
