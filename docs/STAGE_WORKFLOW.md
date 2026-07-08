# STAGE WORKFLOW

This document defines the standard workflow for executing any Ophir project
Stage. Use it together with `docs/PROJECT_CONSTITUTION.md`.

## 1. Read Documentation

Before starting any Stage, read and follow:

- `docs/PROJECT_CONSTITUTION.md`
- `docs/STAGE_WORKFLOW.md`

## 2. Preflight

Run the required preflight checks:

- verify the current directory;
- run `git status --short`.

## 3. Working Tree

If the working tree is clean:

- continue with the Stage.

If the working tree contains changes:

- identify every changed file;
- determine whether each change belongs to the current Stage.

If any change belongs to another Stage:

- stop;
- list the discovered changes;
- do not run `git add .`;
- ask the user how to proceed.

Never automatically mix changes from different Stages.

## 4. Implementation

Implement only the Scope of the current Stage.

Do not change anything outside the current Stage Scope.

## 5. Validation

After changes are complete, run all mandatory checks required by:

- `docs/PROJECT_CONSTITUTION.md`

## 6. Git Checkpoint

Before creating a checkpoint, confirm that the working tree contains only
changes from the current Stage.

After successful validation, create the Git Checkpoint according to:

- `docs/PROJECT_CONSTITUTION.md`

## 7. Completion

A Stage is complete only after:

- all required checks pass;
- the Git Checkpoint succeeds;
- the working tree is clean.
