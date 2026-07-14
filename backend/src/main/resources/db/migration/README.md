# Flyway migration manifest

`V001__baseline_current_schema.sql` is the frozen P0 copy of `docs/schema.sql`.
Existing non-empty databases may be baselined at version `1` only after their
P0 inventory and checksum match the frozen baseline. Automatic baseline and
`flyway clean` are disabled in `application.properties`.

| Phase               | Expand    | Backfill  | Constraints / contract |
| ------------------- | --------- | --------- | ---------------------- |
| P1 master data      | `V100` ✅ | `V110` ✅ | `V120` ✅              |
| P2 product          | `V200` ✅ | `V210` ✅ | `V220` ✅              |
| P3 rental           | `V300` ✅ | `V310` ✅ | `V320` ✅              |
| P4 transactions     | `V400` ✅ | `V410` ✅ | `V420` ✅              |
| P5 inventory/policy | `V500` ✅ | `V510` ✅ | `V520` ✅              |
| P6 review/article   | `V600` ✅ | `V610` ✅ | `V620` ✅              |
| P7 legacy removal   | owner waiver recorded ✅ | final verification ✅ | `V700` ✅             |

P1 is complete. `V100` expands normalized masters and migration evidence
tables, `V110` performs the fixture/backfill and records non-unique legacy
location names in quarantine, and `V120` adds fixed-name constraints and FK
indexes. The P1 verification queries are in `docs/database/validation/` and the
signed-off results are in `docs/database/p1-execution-report.md`.

P2 is complete. `V200` expands normalized equipment, campground tag and store
stock structures, `V210` loads the frozen catalog and retains validation-only
source evidence in the `migration` schema, and `V220` reconciles the copy before
removing legacy catalog JSONB/cache columns and installing fixed-name
constraints and `product_stock_summary`. P2 evidence is in
`docs/database/p2-execution-report.md`.

P3 is complete. `V300` expands the separate rental variant, campground rental
location, stock and listing structures, `V310` performs the frozen fixture
backfill and retains mapping evidence, and `V320` reconciles the copy before
contracting the legacy rental structures and installing the compatibility view,
fixed-name constraints and campground-location type guards. P3 evidence is in
`docs/database/p3-execution-report.md`.

P4 is complete. `V400` expands normalized order, coupon, booking, calendar and
reservation-ledger structures, `V410` loads the frozen transaction sources and
approved reconciliation evidence, and `V420` proves the backfill before
switching the public tables, installing fixed-name constraints/indexes and
creating the authoritative coupon, customer-tier and product-stock views. P4
evidence is in `docs/database/p4-execution-report.md`.

P5 is complete. `V500` expands normalized policy, availability, minimum-stock,
single-domain movement, conversion and migration-evidence structures; `V510`
performs the deterministic source backfill; and `V520` reconciles and switches
the public tables, installs constraints/indexes, lifecycle guards,
compatibility views and the parameterized availability function. P5 evidence
is in `docs/database/p5-execution-report.md`.

P6 is complete. `V600` expands normalized formal/legacy review and article
targets, `V610` loads the frozen sources with the exact `REV031`/37-row
disposition, and `V620` reconciles and switches the public tables, installs
constraints/read-only guards and exposes review/article/movement DTO views.
P6 evidence is in `docs/database/p6-execution-report.md`.

P7 is complete under the repository owner's explicit waiver of deployed
observation and organizational sign-off. `V700` records that authorization,
archives `movement_migration_map` under the read-only `migration` schema and
removes the temporary public compatibility views. The final reproducible
snapshot is `docs/schema_copy.sql`; A (V001-V700), B (explicit baseline then
V100-V700), and C (snapshot only) have the same canonical catalog. The waiver
is not production observation evidence. Final results are in
`docs/database/p7-execution-report.md`.

Applied migration files are immutable; corrections use a higher, previously
unused version. Do not regenerate or edit any applied backfill or migration
after application.
