# Bank Integration Architecture

## Назначение

Этот документ описывает целевую архитектуру будущей банковской интеграции и ее
влияние на Dashboard.

Ophir сейчас работает с ручными финансовыми событиями. В будущем продукт должен
поддерживать автоматический импорт доходов и расходов из банковских карт и
счетов, не ломая текущую модель Operations и не превращая Dashboard в слой
интеграционной логики.

## Текущий источник данных

Сейчас источником финансовых данных являются manual recorded operations.

Пользователь вручную создает операции, указывая сумму, тип, дату, валюту,
категорию и, если применимо, счет. Эти операции являются recorded view of
finances: они отражают то, что пользователь внес в Ophir.

Dashboard V1 должен показывать recorded balance, а не bank balance.

## Будущий источник данных

Позже появятся bank imported operations: операции, автоматически полученные из
подключенных банковских карт и счетов.

Bank imported operations должны входить в общую финансовую картину, но не
должны автоматически смешиваться с ручными операциями без правил
сопоставления. Банковский импорт является дополнительным источником фактов, а
не заменой всей domain model.

## Operation Source

Operation должна иметь понятие источника:

```text
OperationSource
├── manual
└── bankImported
```

`manual` означает, что операция создана пользователем вручную.

`bankImported` означает, что операция получена из внешнего банковского
провайдера.

Источник операции нужен для:

- корректного расчета балансов;
- поиска дублей между ручным вводом и импортом;
- объяснения пользователю происхождения данных;
- reconciliation между recorded balance и bank balance;
- защиты Dashboard от неявного двойного учета.

## Balance Model

### Dashboard V1

Dashboard V1 показывает recorded balance.

```text
recorded balance =
данные, рассчитанные из recorded operations и account initial balances
```

Recorded balance не должен называться bank balance. Он показывает состояние
денег по данным, которые уже записаны в Ophir.

### После bank integration

После банковской интеграции система должна различать:

```text
recorded balance
bank balance
difference / reconciliation
```

`recorded balance` — баланс, рассчитанный из операций Ophir.

`bank balance` — баланс, полученный от банковского провайдера или связанного
банковского счета.

`difference / reconciliation` — расхождение между recorded balance и bank
balance, которое требует объяснения, сопоставления операций или пользовательского
действия.

Dashboard после интеграции должен показывать не просто сумму, а финансовое
состояние:

- что известно из записанных операций;
- что сообщил банк;
- есть ли расхождение;
- какое действие рекомендуется сделать.

## Deduplication And Matching

Deduplication/matching не должен жить в UI.

Сопоставление manual operations и bank imported operations является domain
responsibility. UI может показывать результат сопоставления и запрашивать
решение пользователя, но не должен содержать правила поиска дублей.

Domain matching должен учитывать:

- account;
- amount;
- operation type;
- occurred date или date window;
- currency;
- merchant/description/note;
- external transaction identity;
- статус pending/posted, когда он появится.

Matching не должен молча удалять или переписывать пользовательские данные.
Безопасная модель — помечать возможные совпадения и предлагать пользователю
reconciliation action.

## Categories For Imported Transactions

Bank categories не являются источником аналитической истины.

Источник истины для аналитики — `Category.analyticsGroup`.

Bank/provider category может использоваться только как входной сигнал для
предложения категории. Она не должна напрямую управлять Statistics, Dashboard,
Budget, Forecast или Recommended Actions.

Правильный поток:

```text
bank transaction
→ provider category / merchant / description
→ category suggestion
→ Category
→ Category.analyticsGroup
→ analytics, insights, dashboard summary
```

Если категория назначена автоматически, система должна быть готова показать
низкую уверенность или попросить пользователя подтвердить выбор.

## Dashboard Boundary

Dashboard должен получать готовую financial summary из domain/services.

Dashboard UI не должен:

- знать детали Plaid или другого провайдера;
- выполнять sync;
- искать дубли;
- назначать категории imported transactions;
- считать reconciliation rules;
- смешивать provider categories с `Category.analyticsGroup`.

Dashboard UI должен отображать уже подготовленные presentation models:

- recorded balance;
- bank balance, когда он появится;
- difference/reconciliation state;
- cash flow;
- insights;
- recommended actions.

## Provider-Specific Logic

Plaid/provider-specific логика не должна попадать в Dashboard UI.

Provider-specific поведение должно быть изолировано в integration/data layer:

- provider connection;
- token handling;
- webhook handling;
- provider account mapping;
- external transaction mapping;
- sync status;
- provider errors.

Domain слой получает нормализованные банковские данные и превращает их в
финансовый смысл Ophir.

## Что Не Добавлять Сейчас

Сейчас не нужно добавлять Plaid-specific поля заранее.

Запрещено преждевременно расширять текущую domain model полями, которые
принадлежат конкретному провайдеру, если интеграция еще не реализуется:

- Plaid item id;
- Plaid access token;
- Plaid account id;
- Plaid transaction id;
- provider-specific category id;
- webhook cursor;
- provider raw payload inside Dashboard models.

До начала реальной интеграции достаточно зафиксировать архитектурные границы:

- операции могут иметь разные источники;
- Dashboard V1 показывает recorded balance;
- bank balance появится как отдельный источник истины;
- reconciliation является domain behavior;
- provider logic не попадает в UI.

## Запрещено

- Называть recorded balance банковским балансом.
- Складывать manual и bank imported operations без matching strategy.
- Реализовывать deduplication в Dashboard UI.
- Использовать bank categories как аналитическую истину.
- Привязывать Dashboard к Plaid или другому конкретному провайдеру.
- Добавлять provider-specific поля до появления реальной интеграции.
