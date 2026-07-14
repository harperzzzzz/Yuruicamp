# P0 execution report

Date: 2026-07-14  
Overall status: **COMPLETE — superseded approval audit passed**

The technical baseline artifacts were created without modifying
`docs/schema.sql`, application UI code, or `data/**/*.json`. The later approval
and coverage audit in `p0-completion-audit.json` records `complete: true`, no
pending decisions and no blockers; it supersedes the pre-approval gate state
that this report originally recorded.

## Frozen baseline

| Artifact                                    | Result                                                             |
| ------------------------------------------- | ------------------------------------------------------------------ |
| `docs/schema.sql` SHA-256                   | `2707c5ee9c152fec7e75b1207b19a4971a9bd51cca910151039a66e6da88e2f6` |
| `docs/schema_copy.sql` SHA-256              | Same as frozen schema                                              |
| `V001__baseline_current_schema.sql` SHA-256 | Same as frozen schema                                              |
| Current schema inventory                    | 30 tables, 13 project ENUMs, 9 explicit indexes                    |
| JSON baseline                               | 17 files, 987 logical rows under the documented counting rule      |
| Baseline report SHA-256                     | `c0d70ca57f90cdc158429193bdb747f5c4c8e624dd2cb8ed3ad4e63766ba1aa7` |

The complete per-file checksums, byte sizes, logical row counts, and JSON field
paths are stored in `p0-baseline.json`.

## Validation results

| Gate                                      | Result | Evidence / note                                                                                                                             |
| ----------------------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| JSON FK and contract validation           | PASS   | 0 errors                                                                                                                                    |
| Listing stock reconciliation              | PASS   | 0 differences; read-only                                                                                                                    |
| Article product ID normalization check    | PASS   | 0 differences; read-only                                                                                                                    |
| Phase 1 normalization check               | PASS   | 0 differences; read-only                                                                                                                    |
| Negative FK test                          | PASS   | Injected unknown `orders.customerId` returned exit code 1 and identified ID + field                                                         |
| Read-only guarantee                       | PASS   | `git diff --exit-code -- data` returned 0 after all checks                                                                                  |
| P0 baseline drift check                   | PASS   | Report hash matched                                                                                                                         |
| `docs/schema.sql` PostgreSQL 18 execution | PASS   | Isolated empty database created 30 tables and 13 project ENUMs                                                                              |
| `V001` PostgreSQL 18 execution            | PASS   | Isolated empty database completed with `ON_ERROR_STOP=1`                                                                                    |
| Schema inventory equivalence              | PASS   | `schema.sql` and `V001` inventory outputs matched before the presentation-only FK action labels were expanded                               |
| Business baseline SQL syntax              | PASS   | Executed against the empty baseline schema; JSON-source financial/stock baseline has 0 issues and records all 9 `C001-C009` mappings        |
| Frontend production build                 | PASS   | Vite 6.4.3 build completed; existing non-module script warnings remain                                                                      |
| Existing `npm run smoke` equivalent       | PASS   | Updated the stale source assertion from `_getProducts` to the implemented shared loader `_loadProductsRaw`; no application behavior changed |
| Maven wrapper                             | PASS   | Fixed non-symlink `.m2` handling; `backend\mvnw.cmd -version` resolves Maven 3.9.16 successfully                                            |
| Spring Boot compile                       | PASS   | Spring Boot 4.1.0 compiled on the available JDK 21 using the non-persistent `-Djava.version=21` override                                    |
| Flyway migrate / validate                 | PASS   | Isolated PostgreSQL 18.4 applied V001; a second startup validated history and reported schema up-to-date with no reapplication              |
| Backend integration test                  | PASS   | `BackendApplicationTests`: 1 test, 0 failures/errors; Hibernate `ddl-auto=validate` initialized successfully                                |
| Target migration allocation               | PASS   | All 67 target objects are assigned to P1-P7 migration ranges                                                                                |
| Executable field dictionary coverage      | PASS   | Completion audit covers all 71 target objects with no missing or extra field dictionaries                                                  |
| Decision gate                             | PASS   | Completion audit contains no pending decisions or blockers                                                                                 |

Commands were executed with the bundled Node runtime because `node`/`npm.cmd`
are not present on this machine's PATH. The package scripts remain standard
`node ...` commands and can be run normally in the project development shell.

## Created controls

- Four P0 data commands are present and default to read-only:
  `validate:data`, `check:listings`, `check:articles`, and `check:normalize`.
- Mutation commands require an explicit `--write`, exposed through
  `sync:listings`, `fix:articles`, and `normalize:data`.
- `application.properties` enables Flyway validation, disables automatic
  baseline and clean, rejects missing locations/out-of-order migration, and
  fixes Hibernate at `ddl-auto=validate`.
- `p0-schema-inventory.sql` emits a machine-readable JSON inventory including
  FK update/delete actions and referencing-index presence.
- `p0-business-baseline.sql` emits discrepancies with domain, data ID, field,
  reason, and disposition status.
- JSON-to-SQL mapping and P1-P7 migration allocation are machine-readable.
- `p0-completion-audit.json` machine-checks schema copies, validation scripts,
  safety properties, migration allocation, field-dictionary coverage, and
  decision status. Its current result is complete with no blockers.

## Gate closure

The authoritative evidence is `p0-completion-audit.json`. It records all 71
target objects as allocated and documented, all decisions as approved, and no
remaining P0 blocker. P1 through P6 were subsequently executed and validated.
