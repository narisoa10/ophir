# ADR-004: Soft Delete

## Status

Accepted

## Scope

This ADR explains why Ophir uses soft delete. The normative lifecycle and usage
rules live in `docs/architecture/soft_delete.md`.

## Problem

Hard delete финансовых операций приводит к необратимой потере данных,
нестабильной аналитике и плохому UX восстановления после ошибки пользователя.

## Options Considered

1. Использовать hard delete сразу из основного UI.
2. Помечать записи boolean-флагом `is_deleted`.
3. Использовать soft delete через `archived_at`.

## Decision

Выбран soft delete через `archived_at`. Основные экраны работают только с
активными записями, архивные записи сохраняются для восстановления и будущего
Archive Screen.

## Why

`archived_at` хранит не только факт архивирования, но и время события. Это
позволяет строить историю, восстановление и будущие фильтры архива.

## Consequences

- Обычный delete переводит запись в Archived.
- Running balance и аналитика основных экранов исключают archived records.
- Restore очищает `archived_at`.
- Permanent delete требует отдельного ADR и UX для Archive Screen.
