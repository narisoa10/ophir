# Dashboard Architecture

## Назначение

Dashboard — главный экран персонального финансового ассистента Ophir.

Dashboard не является набором независимых карточек. Он должен собирать
финансовые данные в единую ассистентскую картину и помогать пользователю
понять:

- что сейчас происходит с деньгами;
- почему это происходит;
- что может произойти дальше;
- что рекомендуется сделать.

Каждый блок Dashboard должен иметь финансовый смысл и поддерживать одну из этих
ролей. Блок без ассистентской функции не должен добавляться на Dashboard только
ради визуального заполнения экрана.

## Источники данных V1

Dashboard V1 строится на текущих данных Ophir:

- manual recorded operations;
- accounts and initial balances;
- categories;
- `Category.analyticsGroup`;
- recurrence flags on operations.

Dashboard V1 показывает recorded balance, а не bank balance.

Recorded balance — это баланс, рассчитанный по данным, которые уже записаны в
Ophir. После банковской интеграции bank balance будет отдельным источником
финансовой истины и не должен смешиваться с recorded balance без reconciliation.

## Слойность

Dashboard UI не должен содержать финансовые формулы.

Правильный поток данных:

```text
Operations / Accounts / Categories
↓
Domain services
↓
Dashboard financial summary
↓
Presentation models
↓
Dashboard UI
```

Dashboard должен получать готовую financial summary из domain/services.

Domain/services отвечают за:

- balance calculations;
- cash flow calculations;
- category analytics;
- recurring/upcoming signals;
- insights;
- recommended actions;
- reconciliation state после bank integration.

Presentation отвечает за:

- форматирование сумм;
- labels;
- empty states;
- порядок отображения;
- severity/priority для UI.

UI отвечает только за rendering и пользовательские события.

## Dashboard V1 Structure

### Header

Назначение: персональный вход в финансового ассистента.

Содержит:

- дату;
- greeting;
- имя пользователя;
- avatar;
- future notification entry point.

Header не является финансовым блоком, но задает контекст главного экрана.

### Today

Назначение: ответить на вопрос "что сейчас происходит с моими деньгами?".

Использует:

- операции за текущий день;
- income;
- expenses;
- transfers;
- categories.

V1 может показывать:

- net today;
- income today;
- expenses today;
- количество операций;
- самый заметный сегодняшний financial signal.

Будущее развитие:

- daily budget state;
- unusual spending detection;
- day forecast;
- reminder about expected payments.

### Recorded Balance

Назначение: показать текущее recorded состояние денег в Ophir.

Использует:

- account initial balances;
- manual recorded operations;
- operation type;
- operation account links;
- currency.

V1 показывает recorded balance, а не bank balance.

Будущее развитие:

- bank balance;
- recorded vs bank difference;
- reconciliation actions;
- account-level balance health.

### Cash Flow

Назначение: объяснить, почему финансовое состояние меняется.

Использует:

- operations for selected period;
- income totals;
- expense totals;
- `Category.analyticsGroup`;
- currency.

V1 может показывать:

- income for period;
- expenses for period;
- net cash flow;
- largest analytics groups;
- essential/flexible/lifestyle split.

Будущее развитие:

- comparison with previous periods;
- recurring vs one-time flow;
- income stability;
- burn rate;
- forecasted cash flow.

### Insights

Назначение: превратить операции в объяснения.

Использует:

- financial summary;
- category analytics;
- period totals;
- largest operations;
- trend signals.

V1 может показывать rule-based insights:

- самая большая категория расходов;
- положительный или отрицательный monthly cash flow;
- крупная операция периода;
- расходы выше обычного уровня, если достаточно данных.

Будущее развитие:

- AI-generated explanations;
- anomaly detection;
- budget-aware insights;
- goal-aware insights;
- forecast-aware insights.

### Upcoming / Recurring

Назначение: ответить на вопрос "что будет дальше?".

Использует:

- `isRecurring`;
- recurrence;
- occurred date;
- amount;
- type;
- category.

V1 может показывать recurring operations как upcoming-lite.

Будущее развитие:

- полноценный schedule engine;
- expected payment dates;
- bills calendar;
- skipped occurrences;
- forecast impact on balance.

### Recommended Actions

Назначение: ответить на вопрос "что мне рекомендуется сделать?".

Использует:

- financial summary;
- insights;
- uncategorized operations;
- recurring signals;
- balance and cash flow state.

V1 может показывать rule-based actions:

- назначить категории операциям без категории;
- проверить крупную трату;
- посмотреть расходы в крупнейшей analytics group;
- добавить recurring operation;
- проверить отрицательный cash flow.

Будущее развитие:

- AI recommendations;
- reconciliation actions after bank integration;
- budget correction actions;
- goal contribution recommendations;
- forecast risk actions.

## Bank Integration Boundary

После bank integration Dashboard должен различать:

- recorded balance;
- bank balance;
- difference/reconciliation.

Provider-specific логика, например Plaid, не должна попадать в Dashboard UI.
Dashboard получает только нормализованную financial summary и presentation
models.

Deduplication/matching между manual operations и bank imported operations не
живет в Dashboard UI. Dashboard может показывать результат matching и
recommended action, но правила сопоставления находятся в domain/services.

Bank categories не являются источником аналитической истины. Dashboard строит
аналитику на `Category.analyticsGroup`.

## Запрещено

- Делать Dashboard набором независимых карточек.
- Считать balance, cash flow или insights внутри UI.
- Называть recorded balance банковским балансом.
- Помещать Plaid/provider-specific логику в Dashboard.
- Использовать bank categories вместо `Category.analyticsGroup`.
- Реализовывать deduplication/matching в Dashboard UI.
- Добавлять блок на Dashboard без ответа на один из ключевых вопросов
  пользователя.
