# Project Rules

## Назначение

Это главный краткий свод инженерных правил Ophir. Он не заменяет детальные
architecture documents. Если нужно понять правило быстро, читать этот документ.
Если нужно изменить правило, обновлять документ-владелец и, при архитектурном
изменении, добавлять ADR.

## Documentation First

- Сначала Documentation. Потом Code.
- При конфликте между кодом и документацией сначала обновляется документация,
  затем после утверждения меняется код.
- Любое архитектурное изменение сопровождается ADR.
- ADR объясняет почему, architecture document определяет как.
- Временное расхождение кода со стандартом фиксируется как `Текущее ограничение`
  или `Планируемое изменение`.

## Architecture

- Любое решение должно масштабироваться.
- Domain model является источником смысла финансовых сущностей.
- UI не содержит бизнес-логику.
- Domain содержит вычисления и финансовые правила.
- Presentation готовит данные для UI.
- Repository работает только с данными.
- Supabase хранит данные, но не диктует UI и domain model.
- Derived data, например Statistics, не является первичным источником истины.

## UI Standards

- Theme - единственный источник Design Tokens.
- Все размеры идут через Theme.
- Все цвета идут через Theme.
- Typography строится по ролям, а не по экранам.
- Не использовать raw значения в feature-коде.
- Не создавать feature-specific Theme tokens.
- Не создавать feature-specific Typography.
- Не исправлять архитектурную проблему styling-хаками.

## Domain Rules

- Operations являются основным источником финансовых событий.
- Running balance и финансовые формулы находятся в Domain.
- Category имеет независимые `uiGroup` и `analyticsGroup`.
- UI использует только category UI grouping.
- Analytics использует только category analytics grouping.
- Soft delete выполняется через `archived_at`.
- Archived records не участвуют в обычных active calculations.

## Data And Localization

- Все user-facing строки проходят через l10n.
- Repository не форматирует display text.
- Presentation применяет formatting, locale и display preferences.
- Supabase changes требуют проверки domain impact.
- Database mapping не должен протекать в UI.

## Code Rules

- Один файл = один class.
- Использовать `const` везде, где это возможно.
- Не дублировать financial calculations.
- Не передавать database models напрямую в widgets.
- Не создавать локальные helpers, которые обходят Theme, Typography или Domain.
- Новые reusable rules добавляются в shared architecture, а не в feature-local
  exceptions.

## Документы-владельцы

- Product principles: `project_philosophy.md`.
- Domain entities and ownership: `domain_model.md`.
- Tokens: `theme.md`.
- Typography: `typography_standard.md`.
- Spacing: `spacing_standard.md`.
- Colors: `color_standard.md`.
- Categories: `category_architecture.md`.
- Operations: `operation_architecture.md`.
- Soft delete: `soft_delete.md`.
- Code style and layer boundaries: `code_standard.md`.
- Feature process: `feature_workflow.md`.

## Запрещено

- Начинать feature с UI без проверки документации.
- Использовать существующий legacy code как оправдание для нового legacy code.
- Добавлять архитектурное правило только в PR description или issue.
- Создавать второй источник истины в reference, README приложения или comments.
