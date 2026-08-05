# Domain Model

## Назначение

Этот документ описывает целевую доменную модель Ophir: основные сущности,
связи между ними, владельцев данных и место бизнес-логики. Он не описывает UI,
database schema или DTO. Для операций слойность уточняется в
`operation_architecture.md`, для категорий - в `category_architecture.md`.

## Общая схема

```text
User
│
├── Accounts
│
├── Operations
│   │
│   └── Category
│
├── Budgets
│
├── Goals
│
├── Statistics
│
└── Settings
```

## User

Ответственность: представляет владельца финансового пространства Ophir.
Пользователь является корнем доступа к данным и контекстом для accounts,
operations, budgets, goals, statistics и settings.

Связи: владеет всеми пользовательскими финансовыми сущностями. Один User может
иметь несколько Accounts, Operations, Budgets и Goals.

Владелец данных: User owns the data. Repository и Supabase хранят данные от
имени пользователя, но не владеют domain meaning.

Бизнес-логика: правила доступа, ownership и user-scoped filtering относятся к
Domain. Auth implementation и session handling относятся к infrastructure/data
слою.

## Accounts

Ответственность: описывают финансовые контейнеры пользователя: cash, card,
bank account или другой источник баланса.

Связи: принадлежат User. Operations должны быть связаны с Account, если они
влияют на баланс конкретного источника денег.

Владелец данных: User владеет accounts. Account является domain entity, а не UI
group.

Бизнес-логика: правила balance ownership, account type, account visibility и
участие account в расчетах находятся в Domain. Repository только загружает и
сохраняет account data.

## Operations

Ответственность: фиксируют финансовое событие: income, expense, transfer или
другое изменение денег.

Связи: принадлежат User, обычно связаны с Account и могут иметь Category.
Operations являются основным источником данных для balances, budgets,
statistics, cash flow и future forecast.

Владелец данных: User владеет operations. Domain владеет смыслом operation type,
amount, date, category, account и archive state.

Бизнес-логика: formulas, running balance, totals, validation, period logic и
financial calculations находятся в Domain. Presentation готовит операции для UI.
Repository выполняет persistence и mapping.

## Category

Ответственность: описывает финансовый смысл operation и ее отображение в UI.

Связи: Category используется Operations. Category имеет две независимые
классификации: `uiGroup` для интерфейса и `analyticsGroup` для аналитики.

Владелец данных: category data может быть system-defined или user-defined, но
domain meaning принадлежит Category model. UI не владеет category grouping.

Бизнес-логика: classification rules находятся в Domain и описаны в
`category_architecture.md`. UI использует только presentation-ready category
models.

## Budgets

Ответственность: задают финансовые ограничения или план пользователя на период,
category, account или другую аналитическую область.

Связи: принадлежат User. Budgets используют Operations и Category analytics для
расчета spent, remaining и progress.

Владелец данных: User владеет budgets. Budget rules являются domain logic.

Бизнес-логика: расчет budget progress, period boundaries, remaining amount,
overspending и budget status находится в Domain. UI не считает budget state.

## Goals

Ответственность: описывают долгосрочные финансовые цели пользователя:
накопление, погашение, planning target или future milestone.

Связи: принадлежат User. Goals могут использовать Accounts, Operations,
Statistics и Forecast для оценки прогресса.

Владелец данных: User владеет goals. Goal rules принадлежат Domain.

Бизнес-логика: progress, target date, required contribution, feasibility и goal
status находятся в Domain.

## Statistics

Ответственность: агрегируют финансовые данные в аналитические выводы.
Statistics не являются первичным источником данных; они derived domain output.

Связи: принадлежат User context и строятся из Operations, Categories, Accounts,
Budgets и Goals.

Владелец данных: исходными данными владеет User. Statistics владеют только
derived results, которые должны быть воспроизводимы из domain data.

Бизнес-логика: grouping, aggregation, period comparison, trend detection и
financial health signals находятся в Domain.

## Settings

Ответственность: хранят пользовательские предпочтения и product configuration:
locale, currency, display preferences, account visibility и будущие automation
settings.

Связи: принадлежат User и влияют на Presentation, localization, formatting и
feature behavior.

Владелец данных: User владеет personal settings. Product defaults принадлежат
application configuration.

Бизнес-логика: правила применения settings находятся в Domain или Presentation в
зависимости от смысла. Formatting preferences применяются в Presentation.
Financial rules, влияющие на расчеты, применяются в Domain.

## Ownership Rules

- User является корнем владения пользовательскими данными.
- Domain владеет финансовым смыслом и вычислениями.
- Presentation владеет формой данных для UI.
- Repository владеет persistence operations, но не domain meaning.
- Supabase хранит состояние, но не определяет архитектуру приложения.

## Текущее ограничение

Некоторые сущности roadmap, например Budgets, Goals, Forecast и advanced
Statistics, могут быть еще не реализованы полностью. Этот документ описывает
целевую модель, к которой новые features должны приводить проект.

## Запрещено

- Делать UI владельцем domain state.
- Считать Statistics первичным источником финансовых данных.
- Привязывать domain model напрямую к Supabase column names.
- Реализовывать Budgets или Goals как screen-only data.
- Дублировать business logic между Dashboard, Statistics и Operations.
