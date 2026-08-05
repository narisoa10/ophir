# ADR-002: Typography Standard

## Status

Accepted

## Scope

This ADR explains why typography is role-based. The normative typography roles
and usage rules live in `docs/architecture/typography_standard.md`.

## Problem

Если типографика создается по экранам, приложение быстро получает набор
несовместимых text styles: operations title, dashboard title, budget title и
другие дубли. Это разрушает иерархию и усложняет redesign.

## Options Considered

1. Создавать text styles отдельно для каждого экрана.
2. Использовать raw `fontSize` и `FontWeight` в widgets.
3. Ввести типографику по ролям.

## Decision

Выбрана типографика по ролям: `screenTitle`, `sectionTitle`, `body`,
`bodyStrong`, `caption`, `captionStrong`, `currency`, `currencyStrong`,
`button`.

## Why

Роль описывает функцию текста, а не место его появления. Это позволяет новым
экранам использовать существующую иерархию и сохранять консистентность.

## Consequences

- Новые text styles не создаются под экран.
- Денежные значения используют currency roles.
- Feature-код не задает `fontSize` и `FontWeight` напрямую.
- Новая роль требует обновления typography standard.
