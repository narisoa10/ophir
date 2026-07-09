# Ophir Documentation

`docs/` is the official Single Source of Truth for Ophir architecture.
This directory does not describe the application README and must not be used for
temporary notes. It defines the target architecture the project must converge to.

## Mandatory Rule

When code and documentation conflict, documentation wins as the architectural
source of truth.

The required order is:

1. Update the relevant document in `docs/`.
2. Review and approve the architectural change.
3. Change application code to match the approved documentation.

No feature, refactoring, database change, UI standard or domain rule should be
implemented first and documented later.

## Target Architecture, Not Current State

These documents describe the correct architecture for long-term development.
They do not attempt to mirror every temporary implementation detail.

If the current code differs from a standard, the difference must be documented as
a `Current limitation` or `Planned change` in the document that owns that rule.
The limitation is not a second standard; it is a migration note.

## Document Ownership

Each document has one clear responsibility:

- `architecture/project_philosophy.md` owns product and engineering principles.
- `architecture/project_rules.md` owns the short mandatory engineering rules.
- `architecture/domain_model.md` owns the high-level domain model.
- `architecture/dashboard_architecture.md` owns Dashboard structure, data flow
  and assistant-screen rules.
- `architecture/bank_integration_architecture.md` owns future bank integration
  boundaries, operation sources and reconciliation rules.
- `architecture/theme.md` owns the token system and refers to typography,
  spacing and color documents for detailed token roles.
- `architecture/typography_standard.md` owns text roles.
- `architecture/spacing_standard.md` owns spacing roles.
- `architecture/color_standard.md` owns color roles.
- `architecture/category_architecture.md` owns category classification.
- `architecture/operation_architecture.md` owns operation layering and financial
  computation placement.
- `architecture/soft_delete.md` owns archive and deletion lifecycle.
- `architecture/code_standard.md` owns general coding rules and layer
  boundaries.
- `architecture/feature_workflow.md` owns the feature development process.
- `runtime_recommendation_mode.md` owns Runtime Recommendation Mode rollout
  behavior, dart-define launch commands, production safety, and manual QA.
- `decisions/` owns ADRs: why important decisions were made.
- `reference/` owns non-normative visual and UX references.
- `roadmap/` owns long-term product direction.

If two documents appear to define the same rule, the more specific document is
authoritative. The broader document must link to it instead of redefining it.

## Required Reading

Before changing code, a developer must:

1. Read `project_philosophy.md`.
2. Read `project_rules.md`.
3. Read the specific architecture document for the affected area.
4. Read related ADRs in `decisions/`.
5. Update documentation first when the intended behavior is not already covered.

## Decision Process

New architectural decisions are recorded in `docs/decisions/` as ADRs. The
corresponding standard in `docs/architecture/` must also be updated, because ADRs
explain why a decision was made while architecture documents define how the
project must work now.
