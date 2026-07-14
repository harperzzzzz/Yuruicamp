# P7 local pre-contract rehearsal report (superseded)

Date: 2026-07-14  
Status: **LOCAL PASS — CONTRACT PENDING EXTERNAL EVIDENCE**  
V700 at the time of this rehearsal: **NOT CREATED / NOT AUTHORIZED**

> Historical record: this report describes the gate state before the repository
> owner explicitly waived deployed observation and sign-off. P7 subsequently
> completed with `V700`; use `p7-execution-report.md` for the final result. The
> pre-contract measurements below remain unchanged as historical evidence.

## Entry and scope gates

| Gate | Result |
| --- | --- |
| D-001 through D-014 | PASS — all APPROVED |
| P0 through P6 completion evidence | PASS |
| Unresolved source/data differences | PASS — 0 |
| `docs/schema.sql` frozen checksum | PASS — unchanged |
| `docs/schema_copy.sql` pre-contract guard | PASS — still the frozen baseline placeholder |
| V700 scope guard | PASS — no `V7*.sql` exists |

The P0 report still contained its original pre-approval `PARTIAL` line even
though `p0-completion-audit.json` was already complete with no blocker. P7
corrected that evidence drift without changing the frozen schema or data.

## A/B rebuild and reconciliation

Database A was created empty and Flyway applied 19 versioned migrations from
V001 through V620. Database B was created from the frozen P0 schema, explicitly
baselined at version 1, and Flyway applied the 18 migrations from V100 through
V620. Both Spring Boot/Hibernate runs passed.

| Comparison | A | B | Result |
| --- | --- | --- | --- |
| Canonical catalog SHA-256 | `e0fd3ed7d2ca105ed4f6cde37805c738e33723bec2effb831a508f4b82197a6f` | same | PASS |
| Normalized data SHA-256 | `769ff4886f3fafa2a73fcbe570a38ec4d6faf25593cecdfee840cee0ea8ac17c` | same | PASS |
| P1-P6 source/DTO/business differences | 0 | 0 | PASS |
| Availability comparison | 4,745 rows / 0 differences | same | PASS |

The path comparison excludes migration execution timestamps and current
sequence counters. These are intentionally nondeterministic across independent
runs and are covered strictly by the backup/restore check instead.

## Global verification

| Suite | Result |
| --- | --- |
| `validate_schema.sql` | PASS — 0 issues |
| `validate_seed.sql` | PASS — 0 issues |
| `validate_financials.sql` | PASS — 0 issues |
| `validate_inventory.sql` | PASS — 0 issues |
| `validate_contract.sql` | PASS — 0 issues |
| `validate_business.sql` | PASS — all rollback/negative cases |
| `validate_performance.sql` | PASS — 6 queries, max 0.234 ms, 0 unapproved scans |
| P7 observation pre-contract validator | PASS — pending fixture cannot authorize V700 |
| P7 observation strict validator tests | PASS — valid 2,017-sample case plus 5 negative mutations |
| Source audits and generated backfills P0-P6 | PASS |
| Vite build / ordinary smoke / ESLint | PASS; 0 errors, 17 existing warnings |

The current fixture is not production-sized. Its sequential scans are approved
only for analyzed relations below 1,000 rows. Production-sized performance
evidence remains an external contract gate.

## Backup, restore, browser and recovery drills

The A database produced a 503,054-byte custom backup with SHA-256
`3c0713549db5f83c1880e26f3d23a7f4a83158c03df17d990952cd69fe726451`.
After restore, the exact data fingerprint—including Flyway history, operational
timestamps and sequence state—matched at
`6922f5ac7f95edbcbad0c87b74a2847c592e34216f05544d8bb008a849b590f5`.
All six global suites passed again.

Puppeteer 24.43.1 with installed Chrome passed 68 browser checks and the in-app
browser independently exercised product, article, member review, campground to
rental, admin calendar, analytics, movement and review flows. The first sandboxed
Puppeteer attempt could not load the project's existing CDN dependencies; the
approved network run passed with zero failures.

Spring Boot started successfully in both observation configuration
(`read-new=true`, `write-legacy=false`) and rollback configuration
(`read-new=false`, `write-legacy=true`). A disposable clone validated all
existing checksums, applied a temporary higher V621 migration, and started
successfully. The drill migration was never placed in the production migration
directory.

## Contract gates still pending

Local fixtures cannot prove deployed traffic or organizational approval. The
following evidence is required before V700:

1. Seven consecutive days in `Asia/Taipei`, spanning weekday and holiday.
2. At least 100 observed transactions or approved golden cases.
3. Five-minute reconciliation with sustained zero source/data/DTO differences.
4. Telemetry showing legacy read and write counts remain zero.
5. Production-sized query plans within pre-approved thresholds.
6. Deployed backup/restore plus browser smoke before and after restore.
7. Business and operations signoff with immutable evidence references.

Until those fields are completed in `p7-observation-evidence.json`, C cannot be
built from a final `schema_copy.sql`, V700 cannot be created, the movement map
cannot be archived, and `docs/schema.sql` cannot be replaced.

The executable authorization gate is
`node tests/p7-observation-validator.mjs --require-contract`. Against the
current evidence it intentionally exits `1` with the missing duration, sample,
volume, performance and approval issue codes. This expected failure is part of
the contract guard, not a local test regression.
