# P5 execution report

Date: 2026-07-14  
Status: **COMPLETE — P6 has not started**

P5 normalizes booking policy, blocks, closures and minimum stock; replaces
mixed legacy movement items with single-domain store/rental details and
cross-domain conversions; strengthens reservation and movement lifecycle
boundaries; and exposes compatibility views plus parameterized zone
availability.

## Entry gates and source adjudication

| Gate | Result |
| ---- | ------ |
| P4 complete | PASS |
| D-004, D-005, D-010, D-011 | PASS — APPROVED |
| Sale reservation expiry, location split, cancellation and return inspection | PASS — defined by D-011 and P4 |
| Variant and location source audit | PASS — 0 unclassified rows and 0 guessed variants |
| Business-only ambiguity | NONE — no `BLOCKED` outcome required |

The seven source-derived resolutions are recorded in
`docs/database/p5-decision-log.md`.

## Migration evidence

| Migration | Responsibility | SHA-256 |
| --------- | -------------- | ------- |
| `V500__p5_expand_inventory_policy_schema.sql` | Expand normalized P5 targets and migration evidence | `15cffc7bb8cd11333735ce2bb8c408394785d3bd1bca0311157ac6045662bd4b` |
| `V510__p5_backfill_inventory_policy_data.sql` | Deterministic policy, minimum-stock and movement backfill | `95eddef5477ccc427e2ac2f73029e08e3f5d077cebb7cc544ab42873a9ff6d02` |
| `V520__p5_add_inventory_policy_constraints.sql` | Reconcile, constrain, switch, add lifecycle guards and read APIs | `baa0d49a3f64e2443b26b7db086c86078befe048ebe6dd9a8aa96883994a7ca7` |

Flyway applied every versioned migration from V001 through V520 on a fresh
PostgreSQL 18.4 database. Spring Boot 4.1.0 and Hibernate validation passed. A
second startup validated all checksums, reported schema version 520 and applied
no migration.

## Reconciliation results

| Dataset | Result |
| ------- | -----: |
| Policy / occupying / availability statuses | 1 / 3 / 5 |
| Blocks / closures | 2 / 2 |
| Store / rental minimum-stock rows | 156 / 333 |
| Legacy / normalized movement headers | 100 / 171 |
| Store / rental movement details | 65 / 44 |
| Conversions / reasoned quarantine | 31 / 1 |
| Legacy migration map | 141 exactly-one outcomes |
| Mixed-classification legacy headers | 25 |
| Store-to-camp classified rows | 32 (31 conversion + 1 quarantine) |

## Verification gates

| Gate | Result |
| ---- | ------ |
| `p5-structure.sql` | PASS — 0 issues |
| `p5-data.sql` | PASS — 0 issues |
| `p5-compatibility.sql` | PASS — 0 differences |
| `p5-business-rules.sql` | PASS — 0 issues; negative cases roll back |
| SQL vs `booking-availability.js` | PASS — 4,745 rows, 0 differences |
| P2/P3/P4 data, compatibility and business regression | PASS — 0 issues |
| P0-P5 source and generated-backfill drift guards | PASS |
| Data FK, listings, article and normalization checks | PASS |
| Vite production build / ordinary smoke | PASS; existing non-module script warnings only |
| Spring Boot fresh Flyway + Hibernate validate | PASS — 1 test, 0 failures/errors |
| Spring Boot second startup | PASS — v520 current, no migration necessary |
| P6 scope guard | PASS — 0 P6 target tables |

The optional Puppeteer browser-encoding smoke was not runnable because the
workspace has no installed `puppeteer` package. P5 changes no frontend files;
the production build, ordinary smoke and direct 4,745-row JavaScript/SQL
availability comparison passed.

## Runtime boundary

PostgreSQL owns schema, constraints, idempotency, nonnegative stock, immutable
posted/cancelled movements, terminal reservation protection and derived read
queries. Spring Boot remains responsible for runtime locking, physical stock
updates, reservation creation/fulfilment/release/expiry scheduling and atomic
retry. P5 deliberately does not add controllers, services or frontend writes.

P6 has not been executed and no P6-only table exists.
