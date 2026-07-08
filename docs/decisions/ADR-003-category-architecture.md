# ADR-003: Category Architecture

## Status

Accepted

## Scope

This ADR explains why categories have two independent classifications. The
normative category model and extension rules live in
`docs/architecture/category_architecture.md`.

## Problem

Категории нужны одновременно для удобного UI и корректной аналитики. Одна группа
не может надежно обслуживать обе задачи: UI-группировка может быть удобной для
выбора, но неверной для budget, statistics или forecast.

## Options Considered

1. Использовать одну category group для всего.
2. Дублировать категории под разные сценарии.
3. Разделить классификацию на `uiGroup` и `analyticsGroup`.

## Decision

`Category` имеет две независимые классификации: `uiGroup` для интерфейса и
`analyticsGroup` для аналитики.

## Why

Разделение предотвращает конфликт между UX и финансовым смыслом. UI может
развиваться без риска сломать статистику, а аналитика может уточняться без
изменения picker и визуальной группировки.

## Consequences

- UI использует только `uiGroup`.
- Analytics использует только `analyticsGroup`.
- Добавление категории требует назначения обеих классификаций.
- Ошибка mapping может привести к неверным отчетам, поэтому изменения категорий
  должны проверяться особенно тщательно.
