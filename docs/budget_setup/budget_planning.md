1. Цель

Budget Planning должен:

Собрать стартовые данные пользователя о доходах и обязательных расходах.
Создать первоначальный финансовый план до появления полной истории операций.
Отделить плановые данные от фактических операций.
Рассчитать:
надёжный месячный доход;
обязательные расходы;
минимальные платежи по долгам;
свободный остаток;
финансовое состояние;
рекомендуемое распределение свободного остатка.
Прогнозировать, хватит ли денег до следующего дохода.
Сравнивать план с фактическими операциями.
Уточнять план после появления подтверждённых данных.
Подготовить систему к будущей банковской интеграции.

Основное правило:

PLAN != FACT

Плановые данные не создают фактические операции.

Фактические операции не переписываются планом.

2. Общая архитектура

Общий поток:

Profile
↓
Budget Setup
↓
Budget Plan
↓
Budget Calculation
↓
Financial State
↓
Dashboard

Фактический поток:

Manual Operations / Bank Transactions
↓
Operations
↓
Plan vs Fact
↓
Plan Confirmation or Update

Прогноз:

Current Balance
+ Expected Income
- Expected Mandatory Payments
  = Forecast Balance

Модули проекта:

Profile
Categories
Accounts
Operations
Budget Planning
Dashboard
Bank Connection

Ответственность модулей:

Модуль	Ответственность
Profile	Валюта, timezone, locale, пользователь
Categories	Категории и финансовая роль
Accounts	Счета и текущие балансы
Operations	Только фактические операции
Budget Planning	Опрос, план, расчёты, прогноз, сравнение
Dashboard	Только отображение результатов
Bank Connection	Подключение банка и импорт операций
3. Budget Setup

Budget Setup собирает стартовые данные. Он не выполняет финансовые расчёты.

3.1 Домохозяйство

Вопросы:

Сколько взрослых используют этот бюджет?
Сколько детей используют этот бюджет?
Какой текущий доступный баланс?
Есть ли просроченные обязательные платежи?
Есть ли крупная обязательная трата в ближайшее время?

Не спрашивать:

валюту;
личный или семейный бюджет;
для кого используется конкретный доход.

Валюта берётся из Profile.

3.2 Доходы

Для каждого источника дохода:

Тип дохода.
Чистая сумма после налогов.
Частота.
Следующая дата поступления.
Доход фиксированный или переменный.
Основной или дополнительный.
Добавить ещё один источник дохода.

Типы дохода:

зарплата;
пособие;
пенсия;
алименты;
доход от бизнеса;
аренда;
фриланс;
другой доход.

Частоты:

ежедневно;
раз в неделю;
раз в две недели;
два раза в месяц;
раз в месяц;
каждые N месяцев;
N раз в год;
раз в год;
нерегулярно.
3.3 Жильё

Первый вопрос:

Какой у вас тип жилья?

Варианты:

аренда;
ипотека;
собственное жильё без ипотеки;
проживание с родственниками;
другое.

Для аренды:

сумма;
частота;
следующая дата;
коммунальные включены или нет.

Для ипотеки:

сумма платежа;
частота;
следующая дата;
налог на недвижимость;
взносы кондоминиума;
страхование жилья.
3.4 Коммунальные услуги

Для каждой услуги:

оплачивается или нет;
сумма;
частота;
следующая дата.

Список:

электричество;
газ;
вода;
канализация;
мусор;
интернет;
мобильная связь;
домашний телефон;
страхование жилья;
домашняя безопасность.
3.5 Продукты и базовые нужды

Вопросы:

продукты;
базовая гигиена;
регулярные лекарства;
регулярные медицинские расходы;
базовые бытовые товары.

Для каждого:

сумма;
частота.
3.6 Транспорт

Пользователь выбирает:

автомобиль;
общественный транспорт;
такси как необходимость;
другое.

Для автомобиля:

автокредит;
страховка;
топливо;
парковка;
платные дороги;
регистрация;
обязательное обслуживание.

Для общественного транспорта:

проездной;
регулярные поездки;
частота.
3.7 Долги

Для каждого долга:

тип;
остаток долга;
минимальный обязательный платёж;
частота;
следующая дата;
процентная ставка, если известна.

В обязательную нагрузку входит только минимальный платёж.

3.8 Дети и иждивенцы

Показывается только при наличии детей или иждивенцев.

Вопросы:

детский сад;
школа;
обязательное обучение;
алименты;
лекарства;
регулярные обязательные расходы;
помощь иждивенцам.
3.9 Домашние животные

Показывается только при наличии питомцев.

Вопросы:

корм;
лекарства;
страховка;
регулярный уход;
обязательные расходы.
3.10 Годовые и редкие обязательства

Для каждого:

категория;
сумма;
частота;
следующая дата.

Примеры:

автомобильная страховка;
налог на недвижимость;
регистрация автомобиля;
лицензии;
паспорт;
школьные сборы;
профессиональные членства;
ежегодные медицинские расходы.
3.11 Резерв

Вопросы:

есть ли финансовый резерв;
сумма резерва;
на каком счёте находится;
есть ли просроченные платежи;
есть ли ближайшая крупная обязательная трата.
3.12 Поведение опроса

Опрос должен:

сохранять данные после каждого шага;
позволять продолжить позже;
показывать только релевантные вопросы;
позволять пропуск необязательных вопросов;
показывать прогресс;
показывать итоговую сводку перед завершением;
поддерживать повторное редактирование.
4. Budget Plan

Budget Plan создаётся после завершения опроса.

Он хранит:

4.1 Общие данные
userId;
status;
version;
currencyCode;
createdAt;
updatedAt;
completedAt.

Статусы:

draft
completed
archived
4.2 Домохозяйство
adultsCount;
childrenCount;
currentBalance;
reserveAmount;
overdueAmount;
upcomingLargeMandatoryAmount.
4.3 Источники дохода

Для каждого:

id;
type;
amount;
frequency;
frequencyParameter;
nextDate;
fixedOrVariable;
primaryOrSecondary;
source;
confidence;
categoryId.
4.4 Обязательства

Для каждого:

id;
categoryId;
amount;
frequency;
frequencyParameter;
nextDueDate;
obligationType;
minimumDebtPayment;
overdue;
source;
confidence.

Типы обязательств:

livingExpense
debtMinimum
yearlyExpense
urgentExpense
4.5 Расчётный результат
reliableMonthlyIncome;
monthlyMandatoryExpenses;
monthlyDebtMinimums;
totalMandatoryLoad;
freeAmount;
freeRatio;
mandatoryLoadRatio;
financialState;
recommendedAllocation;
dataConfidence.
5. Budget Calculation

Все формулы находятся в одном расчётном сервисе.

5.1 Нормализация частоты
daily = amount × 365 / 12
weekly = amount × 52 / 12
biweekly = amount × 26 / 12
semiMonthly = amount × 2
monthly = amount
everyNMonths = amount / N
timesPerYear = amount × count / 12
yearly = amount / 12

Для нерегулярного дохода:

history unavailable:
monthly = declared conservative amount

1–2 completed periods:
monthly = minimum observed period income

3+ completed periods:
monthly = median observed period income
5.2 Доход
I = сумма надёжных месячных доходов

Разовые бонусы не входят в надёжный доход.

5.3 Обязательные расходы
M = сумма месячных эквивалентов обязательных расходов
5.4 Минимальные платежи по долгам
D = сумма месячных минимальных платежей
5.5 Общая обязательная нагрузка
C = M + D
5.6 Свободный остаток
R = I - C
5.7 Доля свободного остатка
freeRatio = R / I

Применяется только если:

I > 0
5.8 Доля обязательной нагрузки
mandatoryLoad = C / I
5.9 Правила округления
расчёты выполняются с полной точностью;
пользовательские суммы округляются по правилам валюты;
проценты отображаются с одним десятичным знаком;
промежуточные значения не округляются.
5.10 Централизация

В BudgetRules должны находиться:

коэффициенты частот;
пороги Financial State;
доли распределения;
интервалы повторяемости;
минимальное число подтверждённых циклов;
допустимое отклонение суммы.
6. Financial State

Состояние определяется только по плановым доходам и обязательствам для плановой оценки.

Фактическое состояние позже определяется отдельно по операциям.

6.1 Недостаточно данных
I <= 0
→ noIncomeData
C <= 0
→ insufficientExpenseData
6.2 Большой дефицит
freeRatio < -0.20
6.3 Дефицит
-0.20 <= freeRatio < 0
6.4 Слабое состояние
0 <= freeRatio < 0.05
6.5 Стабильное состояние
0.05 <= freeRatio < 0.15
6.6 Сильное состояние
0.15 <= freeRatio < 0.30
6.7 Профицит
freeRatio >= 0.30
6.8 Распределение свободного остатка

При дефиците:

reserve = 0
flexible = 0
wants = 0
savings = 0

При слабом состоянии:

reserve = 70% R
flexible = 30% R
wants = 0
savings = 0

При стабильном состоянии:

reserveOrDebt = 50% R
flexible = 35% R
wants = 15% R

При сильном состоянии:

reserveDebtGoals = 40% R
flexible = 35% R
wants = 25% R

При профиците:

savingsDebtInvestments = 50% R
flexible = 25% R
wants = 25% R

Распределяется только R.

7. Forecast

Forecast работает по датам, а не только по месячным эквивалентам.

7.1 Входные данные
текущий баланс;
ожидаемые доходы;
ближайшие обязательные платежи;
даты доходов;
даты платежей;
просроченные обязательства;
выбранная дата прогноза.
7.2 Формула
forecastBalance =
currentBalance
+ expectedIncomeUntilDate
- mandatoryPaymentsUntilDate
- overduePayments
  7.3 Расчёт по дням

Для каждого дня:

dayBalance =
previousDayBalance
+ incomeForDay
- mandatoryPaymentsForDay
  7.4 Результат Forecast
  projectedBalance;
  nextIncomeDate;
  firstShortfallDate;
  shortfallAmount;
  triggeringObligationId;
  minimumRequiredAmount;
  forecastStatus.

Статусы:

safe
atRisk
shortfall
insufficientData
7.5 Главные ответы

Forecast должен отвечать:

Хватит ли денег до следующего дохода?
В какой день появится недостача?
Какой платёж вызовет недостачу?
Какая минимальная сумма нужна?
Какой остаток ожидается после ближайшего дохода?
8. Plan vs Fact

Plan vs Fact сравнивает план с реальными операциями.

8.1 Сравнение доходов
incomeVariance = actualIncome - plannedIncome
incomeVarianceRatio =
incomeVariance / plannedIncome
8.2 Сравнение расходов
expenseVariance = actualExpense - plannedExpense
expenseVarianceRatio =
expenseVariance / plannedExpense
8.3 Сравнение даты
dateVarianceDays =
actualDate - plannedDate
8.4 Статусы сравнения
matched
underPlan
overPlan
missingActual
unexpectedActual
dateShifted
8.5 Обновление плана

План не обновляется автоматически после одного отклонения.

Предлагать обновление, если:

есть минимум три похожих фактических цикла;
отклонение повторяется;
пользователь подтверждает изменение.

Пример:

План на продукты: 600 CAD
Факт: 740 CAD
Отклонение: +140 CAD

После подтверждения:

Следующий план: 740 CAD

История фактических операций не меняется.

9. Источники данных

Каждое плановое значение должно иметь источник.

9.1 Источники
declared
manualOperation
bankDetected
confirmed
systemCalculated
9.2 Приоритет
confirmed
> bankDetected with confirmation
> repeated manual operations
> declared
9.3 Использование

declared:

данные из опроса.

manualOperation:

данные из вручную созданных операций.

bankDetected:

данные из банковского импорта.

confirmed:

данные подтверждены пользователем.

systemCalculated:

месячный эквивалент;
медиана;
прогноз;
финансовое состояние.
10. Подтверждение данных

Каждое значение должно иметь уровень доверия.

10.1 Уровни
estimated
partiallyObserved
verified
10.2 Estimated

Используется, если:

данные получены только из опроса;
нет завершённого финансового цикла.
10.3 Partially Observed

Используется, если:

есть минимум один завершённый цикл;
часть доходов или обязательств подтверждена фактом.
10.4 Verified

Используется, если:

есть минимум три подтверждённых цикла;
доход или обязательство повторяется;
пользователь подтвердил соответствие плану.
10.5 Обнаружение повторяемости

Минимум три операции.

Интервалы:

weekly: 6–8 дней
biweekly: 12–16 дней
monthly: 26–35 дней

Дополнительно проверять:

тип операции;
категорию;
описание;
получателя;
сумму;
счёт.
10.6 Допустимое отклонение суммы

Для фиксированных платежей:

max(5 CAD, 5%)

Для переменных платежей:

до 15%

Эти значения должны храниться в BudgetRules.

11. Интеграция с Operations

Operations хранит только факты.

11.1 Operation содержит
type;
amount;
currencyCode;
categoryId;
occurredAt;
accountId;
recurrence;
note;
transfer fields.
11.2 В Operation нельзя хранить
следующую дату платежа;
плановую сумму;
черновик опроса;
резерв;
ожидаемый доход;
плановое обязательство;
статус бюджетного плана.
11.3 Связь Plan и Operation

Плановый элемент может иметь:

matchedOperationIds

Но Operation не обязан знать о Budget Plan.

11.4 Поток
Budget Plan Item
↓
Matching Service
↓
Operation
↓
Plan vs Fact Result
11.5 Ручная операция

После создания операции система:

Определяет возможный plan item.
Сравнивает сумму.
Сравнивает дату.
Обновляет Plan vs Fact.
Не изменяет план без подтверждения.
12. Интеграция с Dashboard

Dashboard ничего не рассчитывает.

Он получает готовые результаты.

12.1 Dashboard показывает
надёжный месячный доход;
обязательные расходы;
свободный остаток;
финансовое состояние;
распределение свободного остатка;
прогноз до следующего дохода;
план против факта;
уровень доверия.
12.2 Первая карточка
Financial State

Показывает:

состояние;
доход;
обязательную нагрузку;
свободный остаток;
короткое объяснение.
12.3 Карточка распределения

Показывает:

обязательные расходы;
гибкие расходы;
желания;
резерв/долги/накопления.
12.4 Карточка Forecast

Показывает:

текущий баланс;
следующую дату дохода;
ближайшие платежи;
ожидаемый остаток;
предупреждение о недостаче.
12.5 Карточка Plan vs Fact

Показывает:

план;
факт;
отклонение;
категории с превышением;
категории ниже плана.
12.6 Dashboard не должен
читать Supabase напрямую;
выполнять формулы;
определять Financial State;
нормализовать частоты;
сопоставлять операции;
обновлять план.
13. Интеграция с Bank Connection

Bank Connection будет отдельным feature.

lib/features/bank_connection/
13.1 Ответственность
подключение финансового учреждения;
хранение внешних счетов;
синхронизация;
импорт транзакций;
дедупликация;
определение источника транзакции;
обновление баланса счёта.
13.2 Bank Connection не должен
рассчитывать бюджет;
определять Financial State;
изменять Budget Plan;
распределять доход;
давать рекомендации.
13.3 Импорт транзакций

Каждая банковская транзакция должна иметь:

externalTransactionId;
externalAccountId;
institutionId;
amount;
currencyCode;
occurredAt;
description;
merchant;
importSource;
syncBatchId;
importedAt.
13.4 Дедупликация

Приоритет:

externalTransactionId.
account + date + amount + normalized description.
manual confirmation при неоднозначности.
13.5 Повторяемость

После минимум трёх похожих операций:

Похоже, этот доход или платёж повторяется.
Добавить его в бюджетный план?

Без подтверждения пользователя план не изменяется.

13.6 Итоговый поток
Bank
→ Imported Transaction
→ Operation
→ Plan Matching
→ Plan vs Fact
→ User Confirmation
→ Optional Plan Update
14. Структура feature
    lib/features/budget_planning/
    ├── controller/
    │   ├── budget_setup_controller.dart
    │   ├── budget_setup_providers.dart
    │   └── budget_plan_provider.dart
    │
    ├── data/
    │   ├── dto/
    │   │   ├── budget_setup_dto.dart
    │   │   ├── budget_income_source_dto.dart
    │   │   └── budget_obligation_dto.dart
    │   ├── mappers/
    │   │   └── budget_planning_mapper.dart
    │   └── repositories/
    │       └── supabase_budget_planning_repository.dart
    │
    ├── domain/
    │   ├── entities/
    │   │   ├── budget_plan.dart
    │   │   ├── budget_income_source.dart
    │   │   ├── budget_obligation.dart
    │   │   └── budget_result.dart
    │   ├── enums/
    │   │   ├── budget_frequency.dart
    │   │   ├── budget_financial_state.dart
    │   │   ├── budget_data_source.dart
    │   │   └── budget_data_confidence.dart
    │   ├── repositories/
    │   │   └── budget_planning_repository.dart
    │   └── services/
    │       ├── budget_rules.dart
    │       ├── budget_calculation_service.dart
    │       ├── cash_flow_forecast_service.dart
    │       └── budget_plan_fact_service.dart
    │
    └── presentation/
    ├── screens/
    │   ├── budget_setup_screen.dart
    │   └── budget_setup_result_screen.dart
    └── widgets/
    ├── budget_setup_progress.dart
    ├── budget_household_step.dart
    ├── budget_income_step.dart
    ├── budget_obligations_step.dart
    ├── budget_reserve_step.dart
    └── budget_summary_step.dart

Правила структуры:

Не создавать отдельный feature для каждой формулы.
Не создавать entity без реального потребителя.
Не создавать service ради одного простого getter.
Не создавать compatibility layer.
Не создавать snapshot, intelligence, diagnostics, strategy, factory без доказанной необходимости.
Все формулы централизованы.
UI не содержит бизнес-логики.
Supabase DTO не используется напрямую в UI.
Supabase

Предварительная минимальная схема:

budget_setups
budget_income_sources
budget_obligations

budget_setups хранит:

household;
reserve;
draft/completed status;
version.

budget_income_sources хранит доходы.

budget_obligations хранит:

обязательные расходы;
долги;
просрочки;
крупные обязательства.

Плановые данные не хранятся в operations.

15. План реализации
    Этап 1. Документация
    Сохранить этот документ в docs/.
    Зафиксировать формулы.
    Зафиксировать пороги.
    Зафиксировать состав опроса.
    Зафиксировать границу PLAN/FACT.
    Этап 2. Supabase schema
    Создать таблицу budget_setups.
    Создать таблицу budget_income_sources.
    Создать таблицу budget_obligations.
    Добавить foreign keys на profiles.id.
    Добавить timestamps.
    Добавить RLS.
    Добавить policies владельца.
    Добавить draft/completed status.
    Добавить version.
    Этап 3. Domain
    Создать frequency enum.
    Создать financial state enum.
    Создать data source enum.
    Создать confidence enum.
    Создать минимальные entities.
    Создать repository contract.
    Создать BudgetRules.
    Создать calculation service.
    Этап 4. Data
    Создать DTO.
    Создать mapper.
    Создать Supabase repository.
    Реализовать сохранение draft.
    Реализовать загрузку draft.
    Реализовать завершение setup.
    Реализовать обновление плана.
    Этап 5. Questionnaire
    Создать основной экран.
    Добавить progress.
    Добавить household step.
    Добавить income step.
    Добавить housing step.
    Добавить utilities step.
    Добавить basic needs step.
    Добавить transport step.
    Добавить debts step.
    Добавить dependants step.
    Добавить pets step.
    Добавить yearly obligations step.
    Добавить reserve step.
    Добавить summary step.
    Добавить save/resume.
    Этап 6. Calculation
    Реализовать нормализацию частот.
    Реализовать reliable income.
    Реализовать mandatory expenses.
    Реализовать debt minimums.
    Реализовать free amount.
    Реализовать ratios.
    Реализовать Financial State.
    Реализовать allocation.
    Добавить unit tests для всех порогов.
    Этап 7. Routing
    Добавить Budget Setup route.
    Добавить Budget Result route.
    Добавить gate после авторизации.
    Если setup не завершён — открыть опрос.
    Если setup завершён — открыть Dashboard.
    Добавить возможность редактирования из Settings.
    Этап 8. Dashboard
    Подключить Budget Plan provider.
    Создать первую карточку Financial State.
    Создать карточку распределения.
    Создать Forecast card.
    Создать Plan vs Fact card.
    Не добавлять расчёты в Dashboard.
    Этап 9. Forecast
    Получить текущий баланс из Accounts.
    Получить будущие доходы.
    Получить будущие обязательства.
    Рассчитать дневной баланс.
    Найти первую недостачу.
    Определить вызывающий платёж.
    Показать результат в Dashboard.
    Этап 10. Plan vs Fact
    Получать фактические Operations.
    Сопоставлять с plan items.
    Рассчитывать отклонения.
    Показывать превышения.
    Запрашивать подтверждение обновления.
    Не обновлять план автоматически.
    Этап 11. Confidence
    После опроса — estimated.
    После одного цикла — partiallyObserved.
    После трёх подтверждённых циклов — verified.
    Показывать уровень доверия пользователю.
    Этап 12. Bank Connection
    Создать отдельный feature.
    Подключить банковского провайдера.
    Сохранять внешние счета.
    Импортировать транзакции.
    Исключать дубликаты.
    Создавать Operations.
    Определять повторяемость.
    Предлагать обновление Budget Plan.
    Не менять план без подтверждения.
    Этап 13. Финальная проверка
    PLAN не записывается в Operations.
    FACT не изменяется рекомендациями.
    Все формулы находятся в одном месте.
    Все пороги находятся в BudgetRules.
    Dashboard не содержит расчётов.
    Bank Connection не содержит бюджетных формул.
    Все таблицы защищены RLS.
    Все состояния покрыты тестами.
    Все тексты локализованы.
    Вся UI-часть использует только Theme_V1.