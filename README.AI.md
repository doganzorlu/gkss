# README.AI.md - MOSB Genel Kurul Sayım Sistemi Engineering Guardrails

This file is for AI agents and automation tooling. It is constraint-driven and intentionally strict.

## 1) Architectural Intent
MOSB Genel Kurul Sayım Sistemi is a desktop-only counting application for **physical ballots**.

- Humans cast votes on paper.
- Operator enters counts from read-aloud ballots.
- Application is projected live for transparency.
- System goal is defensibility and auditability, not throughput.

## 2) Non-Negotiable Domain Constraints
1. Candidate order is fixed by entry order.
2. Candidate list is entered before counting and locked.
3. Vote operation is increment-only (`+1`).
4. No decrement, delete, edit, or undo.
5. Every increment must be user-visible and confirmation-gated.
6. Election lifecycle is strictly linear: `setup -> locked -> counting -> finalized`.
7. Finalized state is read-only.
8. Persistence is local SQLite.
9. Vote ledger is append-only and hash-chained.

## 3) Must NOT Implement
- Online voting or network voting flow
- Authentication/authorization/user-role system
- Admin panel or hidden privileged operations
- Remote control, remote API, or cloud synchronization
- Bulk vote mutation tools
- Smart ranking, AI-assisted result shaping, or predictive logic

## 4) Must Implement (Foundation Scope)
- Deterministic domain model for election states
- Candidate model with immutable `entryOrder`
- Append-only vote ledger records with chain verification fields
- Deterministic tie-break:
  1. Vote count descending
  2. Entry order ascending

## 5) Codebase Conventions
- Code comments: English.
- Human process docs: Turkish.
- Keep business rules in domain layer, not hidden in UI widgets.
- Use explicit naming (`finalizeElection`, `lockCandidates`, `appendVoteRecord`).
- Avoid side effects in UI event handlers; delegate to use-case/service layer.

## 6) Structure Rules
Preferred module direction (initial):

```text
lib/
  app/
    app.dart
  core/
    errors/
    types/
  features/
    election/
      domain/
      application/
      data/
      presentation/
```

Notes:
- This structure is guidance for upcoming implementation.
- Current scaffold may still contain default Flutter starter files.

## 7) Extension Guidelines
Before implementing any change, evaluate:
1. Does this increase transparency?
2. Does it preserve audit trace clarity?
3. Does it reduce or increase operator error risk?
4. Could it be interpreted as manipulation assistance?

If any answer is uncertain, require human approval before coding.

## 8) Human Approval Required For
- Schema changes in `vote_ledger`
- Hash function or chain construction changes
- Lifecycle transition rule changes
- UI flow changes that can hide or bypass confirmation
- Any capability that modifies historical vote records

## 9) Testing Priorities
- Procedural correctness over cosmetic behavior
- Manual scenario checklists are mandatory
- Integrity verification steps must be reproducible and documented
- Automated tests are encouraged, but cannot replace procedural controls

## 10) Security and Trust Positioning
This system is not a trust oracle. It is a constrained counting aid.
Trust comes from:
- physical process,
- public projection,
- append-only evidence,
- and post-election verification.

## 11) Repository Documentation Map
- `README.MS.md`: human-facing operational guidance (Turkish)
- `docs/system_overview.md`: high-level architecture and scope
- `docs/election_rules.md`: hard business rules
- `docs/ui_flow.md`: operational UI flow and failure scenarios
- `docs/data_model.md`: data schema and ledger logic
- `docs/integrity_and_audit.md`: verification and audit procedure
