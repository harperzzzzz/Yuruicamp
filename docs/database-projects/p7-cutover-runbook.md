# P7 cutover, observation and recovery runbook

Date: 2026-07-14  
State: **COMPLETED WITH OWNER WAIVER — V700 APPLIED**

This runbook preserves the original contract procedure. On 2026-07-14 the
repository owner explicitly waived the deployed observation and organizational
sign-off gates and authorized direct finalization. The waiver is recorded in
`p7-waiver-decision.md` and `p7-observation-evidence.json`; it is not represented
as production evidence. `V700` and the final `docs/schema_copy.sql` were then
created and validated. `docs/schema.sql` remains the frozen baseline.

## Fixed feature flags

| Property | Environment variable | Pre-contract | Observation | After authorized contract |
| --- | --- | --- | --- | --- |
| `database.migration.p7.read-new` | `DATABASE_MIGRATION_P7_READ_NEW` | `true` | `true` | `true` |
| `database.migration.p7.write-legacy` | `DATABASE_MIGRATION_P7_WRITE_LEGACY` | `true` | switch to `false` only after reconciliation approval | `false` |

The backend API is the only component allowed to bridge writes. Frontend code
must never write both models. Before stopping legacy writes, the legacy model is
the rollback authority; afterward the normalized model is the sole truth.

## Required order

1. Verify D-001 through D-014 and every P0-P6 execution report.
2. Build database A from an empty cluster using Flyway V001 through the current
   migration head.
3. Build database B from the frozen P0 schema checksum, perform an explicit
   Flyway baseline at version 1, and migrate V100 through the current head.
4. Run global schema, seed, financial, inventory, business and DTO contract
   validation on A and B. Compare canonical catalog dumps byte-for-byte.
5. Run the approved query set with `EXPLAIN (ANALYZE, BUFFERS)` against seed
   volume equal to or greater than production expectations. Record thresholds
   before accepting results; document every permitted small-table sequential scan.
6. Back up A with `pg_dump`, restore into a fresh database, compare canonical
   schema and data checksums, and rerun all validations.
7. Enable normalized reads, retain legacy writes, and reconcile every five
   minutes. Then stop legacy writes through the flag and prove old read/write
   counts and all data/DTO differences remain zero for seven consecutive days,
   spanning weekday and holiday. If traffic is below 100 transactions, execute
   and approve at least 100 golden cases.
8. Run the full browser smoke suite against the deployed candidate and again
   after backup restore. Exercise read switch and rollback while writes are
   paused; exercise a higher-version forward-fix in a disposable clone.
9. Obtain owner approval for source/target counts, observation evidence,
   backup/restore and rollback evidence.
10. Only then create `V700`. It must archive `movement_migration_map` in the
    `migration` schema as read-only, remove public legacy compatibility objects,
    and avoid modifying any applied migration. Repeat A/B/C comparison, where C
    is built solely from the newly generated final `docs/schema_copy.sql`.

## Observation evidence record

Store approved evidence outside generated fixtures and record only references
and checksums in `docs/database/p7-observation-evidence.json`. Required fields:

- observation start/end in `Asia/Taipei`, deployment and database identifiers;
- sample count, golden-case count and weekday/holiday coverage;
- five-minute reconciliation sample count and maximum difference;
- legacy read count, legacy write count and DTO difference count;
- browser smoke result before and after restore;
- backup artifact checksum, restore checksum and rollback result;
- approver identity, approval time and immutable evidence reference.

Missing deployed-environment telemetry, access or approval normally remains a
contract blocker. The owner waiver bypassed these gates without synthesizing
fixtures, telemetry, timestamps or approvals.

Validate the checked-in pending fixture with
`node tests/p7-observation-validator.mjs --pre-contract`. After attaching real,
immutable deployed-environment evidence, the mandatory authorization command is
`node tests/p7-observation-validator.mjs --require-contract`. The latter verifies
at least 2,017 ordered samples, maximum six-minute gaps, seven full days,
weekday/holiday coverage, 100 transactions or golden cases, zero legacy reads,
zero legacy writes, zero reconciliation/DTO differences, production-sized query
plans, matching backup/restore checksums, browser smoke before and after restore,
and separate business and operations approvals. It must pass before anyone
authors `V700`.

## Rollback and forward-fix

Before contract, pause writes, set `read-new=false`, set `write-legacy=true`,
verify health and resume. Never allow two independent writers. After contract,
do not modify or repair an applied migration; create a higher-numbered
forward-fix. Restore a verified backup only for disaster recovery and rerun the
entire validation suite before accepting traffic.

## Final recorded execution

- Owner waiver validator: PASS; external observation fields remain empty and
  explicitly `WAIVED`. The final-state command is
  `node tests/p7-observation-validator.mjs --require-final-waiver`; the original
  `--require-waiver` command remains an authorization-before-V700 guard.
- A/B migration paths: PASS at V700 with Java 25, Flyway and Hibernate.
- A/B/C canonical catalog SHA-256:
  `d9af5722de6f69954a1b330fa0a18c4fed84de55ac13fe8475d08b78e8a14970`.
- `movement_migration_map`: 141 rows archived read-only under `migration`, with
  one reasoned quarantine row and no public relation.
- Backup/restore, all six global SQL suites, 68 browser checks and the final
  snapshot generator check: PASS.
- Final evidence: `docs/database/p7-execution-report.md`.
