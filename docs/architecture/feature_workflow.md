# Feature Workflow

## Назначение

Feature Workflow определяет порядок разработки новой функциональности в Ophir.
Документация обновляется до изменения кода, чтобы feature соответствовала
архитектуре, а не формировала ее случайно.

Этот документ является источником истины для процесса работы. Он не заменяет
архитектурные стандарты отдельных областей, а задает порядок их применения.

Перед началом feature разработчик должен свериться с `project_rules.md`. Этот
workflow описывает последовательность работы, а `project_rules.md` фиксирует
краткие обязательные правила.

## Процесс

### 1. Исследование

Определить пользовательскую задачу, финансовый смысл, ограничения данных и
связанные экраны.

### 2. Проектирование

Описать expected behavior, states, empty states, error states и основные user
flows.

### 3. Архитектура

Определить, какие слои затрагиваются: UI, Presentation, Domain, Repository,
Supabase. Если появляется новое архитектурное решение, создать или обновить ADR.

### 4. Theme

Проверить, какие tokens нужны. Использовать существующие tokens, если их роли
подходят. Новый token добавлять только после обновления Theme docs.

### 5. Typography

Выбрать typography roles. Не создавать screen-specific text styles.

### 6. UI

Собрать интерфейс из готовых presentation data, Theme и typography roles. UI не
содержит формулы и repository calls.

### 7. Presentation

Подготовить display models, adapters, formatting и состояние для UI.

### 8. Domain

Реализовать финансовые правила, формулы, validation, running balance или
analytics logic.

### 9. Repository

Добавить загрузку, сохранение, mapping и обработку data-source errors.

### 10. Localization

Все user-facing строки должны поддерживать localization. Нельзя hardcode text в
production UI, если строка видна пользователю.

### 11. Supabase

Если меняется schema, migration и documentation должны быть согласованы с
domain requirements. Supabase не должен диктовать UI-модель.

### 12. Testing

Покрыть domain logic unit tests. Presentation tests добавляются для сложных
adapters. Repository tests добавляются при изменении data mapping.

### 13. Documentation

Проверить, что architecture docs, ADR и reference обновлены. Документация не
является последним формальным шагом: она должна сопровождать весь процесс.

Если на шаге 13 обнаружено, что код уже изменил архитектуру без документации,
изменение считается незавершенным. Нужно вернуться к шагу 3 и оформить решение.

## Как использовать

Каждая feature проходит этот список. Небольшие UI-only изменения могут
пропускать Domain, Repository и Supabase, но не могут пропускать Theme,
Typography и Documentation review.

## Как расширять

Если новый тип feature требует дополнительных шагов, workflow обновляется до
первого production использования.

## Запрещено

- Начинать с widget implementation без архитектурного решения.
- Добавлять tokens после написания UI.
- Вносить Supabase changes без проверки domain impact.
- Считать documentation необязательной для малых изменений.
