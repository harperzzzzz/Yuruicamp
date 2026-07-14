# P1 execution report

Date: 2026-07-14  
Status: **COMPLETE — P2 has not started**

P1 establishes common masters and normalized references while retaining the
legacy columns needed for rollback and compatibility reads. No P2 migration or
P2 target object was created.

## Migration evidence

| Migration                              | Responsibility                                                       | SHA-256                                                            |
| -------------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `V100__p1_expand_master_data.sql`      | Expand normalized masters, references and migration evidence tables  | `b8327bfb688d56da594b5a3cc0a4d84c0aec14bf130f5e0027e494fa05d6bdff` |
| `V110__p1_backfill_master_data.sql`    | Backfill the frozen JSON fixture set and legacy normalized relations | `2206468abe509149d99814d271b3f4dc26bf31eae52ad8bca6297cb2659bd07d` |
| `V120__p1_constraints_master_data.sql` | Install fixed-name PK/FK/UNIQUE/CHECK constraints and FK indexes     | `d2099b4e756f9b58d82f6bb878cf0361fc91fe2c7f3e5a8569b788db1e220d69` |

Flyway on isolated PostgreSQL 18.4 applied versions `001,100,110,120` and
finished at version `120`. A second Spring Boot startup validated the same
history and reported the schema up to date with no migration or backfill
reapplication. `BackendApplicationTests` passed on both startups.

## Backfill reconciliation

| P1 dataset                      | Rows |
| ------------------------------- | ---: |
| Customers                       |   50 |
| Default shipping addresses      |   50 |
| Preference options              |   18 |
| Customer preference assignments |  200 |
| Customer tag definitions        |    3 |
| Customer tag assignments        |   56 |
| Brands                          |   12 |
| Product categories              |    6 |
| Campgrounds                     |    8 |
| Campground zones                |   13 |
| Branches                        |    3 |
| Branch features                 |    9 |
| Inventory locations             |   16 |

The four legacy administrator identifiers (`01`, `02`, `03`, `admin`) are
seeded as stable technical identities. Because the source fixtures contain no
names or email addresses, their unique emails use the reserved
`@migration.invalid` domain and must be enriched through the future admin
identity workflow rather than guessed during migration.

The backfill generator found 89 `movement.json` endpoints whose historic
campground labels cannot be uniquely mapped to C002-C009. Every occurrence is
recorded in `migration.p1_location_quarantine` with source row, field, raw value,
reason and `PENDING_REVIEW` disposition. Known branch/main/rental warehouse
aliases resolve through `migration.p1_location_aliases`; inbound `進貨` and
outbound `損耗` are explicitly treated as non-physical endpoints. No location
value is silently guessed.

## Verification gates

| Gate                             | Result                                                                                                     |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `p1-structure.sql`               | PASS — 0 issues; all required named constraints and FK indexes present                                     |
| `p1-data.sql`                    | PASS — 0 issues; 89 explicitly quarantined source endpoints                                                |
| `p1-compatibility.sql`           | PASS — 0 customer/address/tag/preference/admin/location DTO differences                                    |
| `p1-business-rules.sql`          | PASS — duplicate default address and invalid location rejected; child cascade and master restrict verified |
| Flyway second startup            | PASS — schema at `v120`, no migration necessary                                                            |
| Spring Boot / Hibernate validate | PASS — 1 test, 0 failures/errors on both startups                                                          |
| P2 scope guard                   | PASS — 0 P2 objects and no V2xx migration files                                                            |
| Source mutation guard            | PASS — `data/**` unchanged                                                                                 |

The application continues to read the legacy DTO shape during P1, as required
by the change-impact matrix. Legacy JSONB and display columns are intentionally
retained; their contract removal remains a P7 concern.
