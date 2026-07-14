# P7 external observation and sign-off waiver

Date: 2026-07-14  
Decision: **APPROVED BY REPOSITORY OWNER**  
Evidence: `codex-thread://019f5e33-e1d2-7411-a6a9-309de86b1e34/user-directive-2026-07-14`

The repository owner explicitly directed P7 to skip the deployed-environment
observation and organizational sign-off portion and proceed directly to the
contract stage. This decision supersedes the earlier P7 requirement that made
those external gates mandatory before authoring V700.

## Waived gates

- seven consecutive deployed-environment days and 2,017 five-minute samples;
- 100 observed transactions or approved deployed golden cases;
- deployed legacy read/write telemetry;
- production-sized deployed query evidence;
- deployed backup/restore browser smoke evidence;
- separate business and operations sign-off.

## Evidence that is not waived

- P0-P6 entry gates and deterministic source classifications;
- local A/B rebuild, full seed and checksum comparison;
- schema, seed, financial, inventory, business and DTO validation;
- local performance fixture and regression suites;
- backup/restore, rollback and forward-fix rehearsal;
- V700 migration safety guards;
- movement map archive integrity and read-only enforcement;
- final A/B/C schema equivalence;
- preservation of `docs/schema.sql` until final snapshot validation completes.

No observation samples or approvals are fabricated by this waiver. Reports
must describe the skipped evidence as `WAIVED`, never as `PASS` or `COMPLETE`.

## Accepted risk

The owner accepts that local deterministic evidence cannot prove real deployed
traffic, production performance, or organizational operational readiness. Any
deployed defect after contract must be corrected with a higher Flyway
forward-fix or a verified disaster-recovery restore; applied migrations must
not be edited or repaired to conceal checksum changes.
