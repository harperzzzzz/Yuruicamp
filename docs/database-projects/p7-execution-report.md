# P7 execution report

Date: 2026-07-14  
Status: **COMPLETE WITH OWNER WAIVER**  
Migration head: **V700**

## Authorization

The repository owner explicitly directed the project to skip deployed
observation and organizational sign-off and proceed to finalization. This is
recorded as an owner waiver in `p7-waiver-decision.md` and
`p7-observation-evidence.json`. No production samples, telemetry, timestamps,
performance results or approvals were fabricated. All locally reproducible P7
gates remained mandatory and passed.

## Contract result

`V700__p7_contract_legacy_schema.sql` has SHA-256
`9a41f3ddee2642de27c623d43c91b3048df318f40b61090cdb695e8cc19efccd`.
It verifies the complete P5/P6 disposition, records the owner-waiver reference,
moves all 141 `movement_migration_map` rows into the `migration` schema, installs
statement-level read-only guards and removes the three temporary P5 public
compatibility views. One archived row remains quarantined with a reason; no row
is unclassified. The archive MD5 is
`9ce8004dfaed9fa401465b1cee1f7c4c`.

The normalized model is now the default read/write authority:
`database.migration.p7.read-new=true` and
`database.migration.p7.write-legacy=false`.

## A/B/C equivalence

| Path | Construction | Result |
| --- | --- | --- |
| A | Empty PostgreSQL 18.4 database, Flyway V001 through V700 | PASS |
| B | Frozen `docs/schema.sql`, explicit Flyway baseline 1, then V100 through V700 | PASS |
| C | Empty database, final `docs/schema_copy.sql` only | PASS |

All three paths produced canonical catalog SHA-256
`d9af5722de6f69954a1b330fa0a18c4fed84de55ac13fe8475d08b78e8a14970`.
A and B produced normalized data SHA-256
`a8c7b5e2e84013c387f0362c43b55fe5d10c616b3dc88e1661c5fef6478cfc2b`.
The catalog comparison covers relations/views, columns, types, nullability,
defaults, logical order, constraints, indexes, enums, sequences, functions and
triggers. Flyway execution history is intentionally excluded.

Both A and B passed Maven/Spring Boot tests under Java 25.0.3. Flyway validated
21 versioned migrations on A and 22 history rows on explicitly baselined B;
Hibernate validated the V700 schema on both.

## Snapshot and recovery

Final `docs/schema_copy.sql` is 237,743 bytes / 6,758 lines with SHA-256
`f838663bb0e5df6b67a8d272149340d2b346530f8844c523dbb31b3eb2ecea1f`.
The reproducible generator check passed. This snapshot is for empty database
creation and comparison only; Flyway remains the only upgrade mechanism.
`docs/schema.sql` was not replaced and remains the frozen baseline.

The V700 custom backup was 504,786 bytes with SHA-256
`1e2de42da4f9298dcb27887eeba9e4c609506867e47811c665179857a7a6d948`.
After restore, the exact database fingerprint matched at
`6e28ea3c336db2e46d1a4dbcaf3aa9bc4540532b0ab58028a34b6b6986d86c26`;
all six global SQL suites passed again with zero issues.

## Verification summary

| Gate | Result |
| --- | --- |
| D-001 through D-014 and P0-P6 entry gate | PASS |
| Schema, seed, financial, inventory, contract and business SQL | PASS — 0 issues |
| P7 archive/contract negative tests | PASS |
| P5 availability reconciliation | PASS — 4,745 rows / 0 differences |
| P6 API, frontend and movement DTO contracts | PASS |
| Performance fixture | PASS — maximum 0.285 ms, threshold 250 ms |
| Backup/restore and exact fingerprint | PASS |
| Browser encoding/full-flow smoke | PASS — 68/68 |
| Vite build and ordinary smoke | PASS |
| ESLint | PASS — 0 errors, 17 pre-existing warnings |
| Final schema generator/check | PASS |

## Residual operational note

External observation, production-sized performance, deployed telemetry and
business/operations sign-off were waived, not passed. A future production
deployment should still execute those sections of `p7-cutover-runbook.md`.
Corrections after V700 must use a higher Flyway version; do not edit applied
migrations, run `repair` to hide checksum drift, or use `flyway clean`.
