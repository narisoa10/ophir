# ADR-005: Code Standard

## Status

Accepted

## Scope

This ADR explains why Code Standard exists. The normative coding rules live in
`docs/architecture/code_standard.md`.

## Problem

Без стандарта код начнет смешивать UI, presentation, domain logic и repository
behavior. В финансовом приложении это особенно опасно: формулы могут
дублироваться, данные форматироваться в неправильном слое, а изменения UI будут
ломать аналитику.

## Options Considered

1. Позволить features самостоятельно выбирать структуру.
2. Фиксировать правила только через code review.
3. Ввести документированный Code Standard.

## Decision

Выбран Code Standard: UI не содержит бизнес-логику, Domain содержит формулы,
Presentation готовит данные для UI, Repository работает только с данными.

## Why

Документированный стандарт делает требования явными до code review. Новые
разработчики могут понять архитектуру через docs, а не через устные договоренности.

## Consequences

- Каждый новый файл должен иметь понятный слой и ответственность.
- Финансовые вычисления централизуются в Domain.
- Feature-specific Theme и Typography запрещены.
- Любое отклонение должно быть задокументировано и обосновано.
