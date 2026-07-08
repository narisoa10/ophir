# ADR-001: Theme

## Status

Accepted

## Scope

This ADR explains why centralized Theme was chosen. The normative rules for
using and extending Theme live in `docs/architecture/theme.md`.

## Problem

Feature-код мог начать использовать raw visual values: colors, spacing, radius,
font size и font weight. Это привело бы к расхождению экранов, дорогим
изменениям design system и невозможности централизованно развивать UI.

## Options Considered

1. Разрешить raw values в feature-коде.
2. Создать локальные theme helpers внутри features.
3. Ввести централизованный Theme на design tokens.

## Decision

Выбран централизованный Theme. Все visual values должны идти через Theme и
ролевые tokens.

## Why

Финансовое приложение должно быть визуально предсказуемым. Централизованные
tokens позволяют менять систему без ручного поиска по экранам и предотвращают
локальные stylistic forks.

## Consequences

- Feature-код не использует `Color(...)`, `EdgeInsets(...)`,
  `BorderRadius(...)`, `fontSize(...)`, `FontWeight(...)`.
- Новые tokens документируются до использования.
- Разработка UI требует проверки существующих tokens.
- Скорость локальной реализации ниже, но стоимость поддержки ниже существенно.
