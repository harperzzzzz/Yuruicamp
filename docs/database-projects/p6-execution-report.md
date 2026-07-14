# P6 execution report

Date: 2026-07-14  
Status: **COMPLETE — P7 has not started**

P6 normalizes verified-purchase and legacy reviews, review photos, article
tags/content/related products, removes the official-reply contract, and moves
the admin movement read model onto the P5 normalized item view.

## Entry gates and source audit

| Gate | Result |
| --- | --- |
| D-002, D-005, D-009, D-012 | PASS — APPROVED |
| Review quarantine list | PASS — `REV031` formal, 37 `NO_ORDER_ID` legacy |
| P5 movement location/variant mapping | PASS — 0 unclassified, 0 guessed |
| P6 source audit | PASS — 0 ambiguous/unclassified reviews and 0 reply payload rows |
| Business-only ambiguity | NONE — no `BLOCKED` outcome required |

The deterministic source resolutions are recorded in
`docs/database/p6-decision-log.md`; counts and mappings are in
`docs/database/p6-mapping-report.md` and `docs/database/p6-source-audit.json`.

## Migration evidence

| Migration | Responsibility | SHA-256 |
| --- | --- | --- |
| `V600__p6_expand_review_article_schema.sql` | Expand normalized P6 targets and frozen source-resolution evidence | `0c0f749feba089976c9cf0f07706b417400d8292fdd8a9c5ce0cdd6c26623fa4` |
| `V610__p6_backfill_review_article_data.sql` | Deterministic 1/37 review and article backfill | `cb00b025175cbff168de62275cf4256d78f7b3db283511811a283836cb011488` |
| `V620__p6_add_review_article_constraints.sql` | Reconcile, constrain, switch, enforce read-only legacy data and expose DTO views | `9c378baa61e36d8c3ecef0cdd7ad67198f0c218444db161c007fe0f2628dea5b` |

Flyway applied all 19 versioned migrations from V001 through V620 to a fresh
PostgreSQL 18.4 database. Spring Boot 4.1.0 and Hibernate validation passed. A
second startup validated all checksums, reported schema version 620 and applied
no migration.

## Reconciliation results

| Dataset | Result |
| --- | ---: |
| Source / formal / legacy reviews | 38 / 1 / 37 |
| Ambiguous / unclassified / unmigrated reviews | 0 / 0 / 0 |
| Formal / legacy photos | 0 / 0 |
| Reply payload rows / reply relations | 0 / 0 |
| Articles / tags / blocks / related products | 6 / 18 / 41 / 16 |
| Text / heading / product blocks | 18 / 12 / 11 |
| Movement DTO headers / normalized items | 171 / 109 |

## Verification gates

| Gate | Result |
| --- | --- |
| `p6-structure.sql` | PASS — 0 issues |
| `p6-data.sql` | PASS — 0 issues |
| `p6-business-rules.sql` | PASS — all positive/negative cases, legacy write rejection and rollback |
| `p6-compatibility.sql` | PASS — 0 review/article/movement DTO differences |
| P1 forward-compatible data/contract checks | PASS — 0 issues |
| P2/P3/P4/P5 data, business and compatibility regression | PASS — 0 issues |
| P4 financial reconciliation | PASS — 0 issues |
| SQL vs JavaScript availability | PASS — 4,745 rows, 0 differences |
| P0-P6 source and generated-backfill drift guards | PASS |
| Data FK, listing, article and normalization checks | PASS |
| P6 frontend/API/movement contract validator | PASS |
| Vite production build / ordinary smoke / targeted ESLint | PASS; existing non-module script warnings only |
| P7 scope guard | PASS — no `V7*.sql` migration exists |

The optional Puppeteer browser-encoding smoke could not run because the current
workspace installation lacks the declared `puppeteer` package. The in-app
browser cannot reach the desktop loopback server and the Chrome connector is
not available; no server was exposed beyond loopback. This is the same tooling
limitation documented in P5 and does not leave a schema, data, DTO, build or
ordinary-smoke failure.

P7 has not been executed. No V700 migration, final contract removal, final
schema replacement, backup/restore exercise or migration-evidence archival was
performed.
