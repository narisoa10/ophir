# Operation Architecture

## Назначение

Operations являются центральной финансовой сущностью Ophir. Архитектура должна
отделять отображение операций от вычислений, хранения и синхронизации.

Этот документ является источником истины для placement rules операций:
где находятся формулы, running balance, adapters, repository logic и Supabase
mapping.

Связи Operations с другими сущностями описаны в `domain_model.md`. Этот документ
не переопределяет domain ownership, а уточняет слойность operation feature.

## Слои

```text
UI
↓
Presentation
↓
Domain
↓
Repository
↓
Supabase
```

## Ответственность слоев

### UI

Отвечает за rendering, input и пользовательские события.

UI получает готовые presentation models и не содержит финансовых формул.

### Presentation

Готовит данные для UI: форматированные суммы, display labels, grouped lists,
empty states, visibility rules и adapters между domain models и widgets.

Presentation не владеет финансовой истиной. Он только преобразует данные для
отображения.

### Domain

Содержит финансовые правила и вычисления:

- формулы;
- running balance;
- totals;
- period calculations;
- category analytics;
- validation business rules;
- future forecast logic.

### Repository

Работает только с данными: загрузка, сохранение, mapping transport models,
обработка ошибок источника данных.

Repository не форматирует UI и не принимает финансовые решения.

### Supabase

Источник хранения и синхронизации. Supabase schema должна отражать domain
requirements, но не должна диктовать UI-структуру.

## Где находятся ключевые элементы

```text
Formulas                 → Domain
Running balance          → Domain
Presentation adapters    → Presentation
Financial calculations   → Domain
Supabase mapping         → Repository
Screen layout            → UI
Display formatting       → Presentation
Persistence              → Repository / Supabase
```

## Как использовать

При добавлении поведения нужно определить слой:

- если меняется внешний вид без изменения данных: UI;
- если меняется подготовка данных для экрана: Presentation;
- если меняется финансовый смысл: Domain;
- если меняется загрузка или сохранение: Repository;
- если меняется структура хранения: Supabase plus documentation.

## Как расширять

Новая operation feature должна начинаться с domain model и правил. UI создается
после того, как определено, какие данные и состояния нужны пользователю.

## Запрещено

- Считать balance в widget.
- Форматировать domain rules внутри repository.
- Привязывать Supabase column names напрямую к UI.
- Дублировать формулы в разных presentation classes.
- Смешивать filters для отображения и filters для analytics без явного
  разделения.

## Текущее ограничение

Если отдельная существующая operation feature временно нарушает слойность, она
не становится допустимым примером. При доработке такой feature код должен быть
перенесен в слой, определенный этим документом.
