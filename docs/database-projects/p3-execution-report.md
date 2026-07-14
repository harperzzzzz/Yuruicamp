# P3 execution report

Date: 2026-07-14  
Status: **COMPLETE — P4 has not started**

P3 separates rental SKU variants from store product variants, establishes the
one-to-one campground rental-location mapping, moves rental physical stock to a
single normalized source, and contracts listings to configuration-only rows
with a compatibility view.

## Entry gates

| Gate                                | Result                                                                 |
| ----------------------------------- | ---------------------------------------------------------------------- |
| P1 and P2 complete                  | PASS — both execution reports are complete                             |
| D-006                               | PASS — APPROVED                                                        |
| D-010                               | PASS — APPROVED                                                        |
| C001-C009 rental-location inventory | PASS — all source codes resolve; C001 is warehouse-only                |
| Rental/equipment/listing mapping    | PASS — all identities and references resolve uniquely; 0 unmapped rows |

The detailed source analysis is recorded in
`docs/database/p3-mapping-report.md`.

## Migration evidence

| Migration                         | Responsibility                                                                                                    | SHA-256                                                            |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `V300__p3_expand_rental.sql`      | Expand rental variants, campground mappings, stock/listing staging and migration-evidence structures              | `5e4688fe0c862a6656dc5112a53d77f0a1db1f04756cb33f393f5d279aa93df8` |
| `V310__p3_backfill_rental.sql`    | Load frozen rental, listing and minimum-stock sources; normalize identities, mappings, stock and listing settings | `9fbac0204984c46f647e2e542d72237e4651324927e56a28e81e92aa99e447b2` |
| `V320__p3_constraints_rental.sql` | Reconcile, install constraints/indexes/type guards, contract legacy tables and create `rental_listing_view`       | `2b8e5b2c8ce06f0edd07922e0af6870b693bd6283f5579405c950b830bf6ec78` |

Flyway on a fresh PostgreSQL 18.4 database applied versions
`001,100,110,120,200,210,220,300,310,320` and finished at version `320`. A
second Spring Boot startup validated the full history and reported the schema
up to date with no migration necessary. `BackendApplicationTests` passed on
both startups.

The generated V310 content is protected by
`admin/scripts/generate-p3-backfill.cjs`: source drift fails the check and must
be handled by a new forward migration after V310 is applied.

## Backfill reconciliation

| P3 dataset                                      | Rows / quantity |
| ----------------------------------------------- | --------------: |
| Rental SKUs                                     |              28 |
| Rental SKU variants                             |              37 |
| Campground rental-location mappings (C002-C009) |               8 |
| Variant/location stock rows                     |             333 |
| Rental physical on-hand quantity                |             534 |
| Rental listings                                 |              16 |
| Resolved rental minimum-stock source rows       |             252 |
| Unmapped or ambiguous source rows               |               0 |

All rental SKU, variant and listing IDs are preserved. Every rental SKU maps
one-to-one to its P2 `equipment_items` identity, while the rental variants live
in a separate namespace and have no foreign key to `product_variants`.

`C001` remains the rental warehouse and is intentionally excluded from
`campground_rental_locations`. `C002-C009` each map to exactly one campground
and remain protected by a constraint trigger that rejects non-campground
locations and later type changes.

The P0 allocation assigns `rental_stock_reservations` to P4 and
`rental_sku_variant_min_stocks` to P5. P3 therefore does not create those
business tables. It retains the fully resolved source evidence in
`migration.p3_rental_min_stock_source` and the rental-variant mapping evidence
needed by later phases.

## Verification gates

| Gate                             | Result                                                                                                                   |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `p3-structure.sql`               | PASS — 0 issues; relations, named constraints, FK indexes, legacy contraction, view types and type guards verified       |
| `p3-data.sql`                    | PASS — 0 issues; 28 rentals, 37 variants, 333 stock rows, 534 total on-hand and 16 listings reconcile                    |
| `p3-compatibility.sql`           | PASS — 0 differences across rental identities, variants, stock, mappings, listings, view DTOs and minimum-stock evidence |
| `p3-business-rules.sql`          | PASS — duplicate/negative/invalid mapping writes rejected; mapped location type and RESTRICT behavior verified           |
| Flyway fresh migration           | PASS — V001 through V320 applied transactionally on a fresh database                                                     |
| Flyway second startup            | PASS — schema at `v320`, checksums valid, no migration necessary                                                         |
| Spring Boot / Hibernate validate | PASS — 1 test, 0 failures/errors on both startups                                                                        |
| P0-P3 source guards              | PASS — baseline, dictionary, audit and all four backfill generators match                                                |
| JSON read-only checks            | PASS — FK/contract, listings, articles and phase-1 normalization checks report 0 differences                             |
| Frontend build / smoke           | PASS — existing non-module script warnings only                                                                          |
| P4 scope guard                   | PASS — no `V4*.sql` file and 0 P4-only target objects created                                                            |
| Source mutation guard            | PASS — `data/**` unchanged                                                                                               |

P3 intentionally does not implement the P4 transaction/reservation model, the
P5 formal minimum-stock table, API bridge-write, feature flags or Spring Boot
CRUD. Those responsibilities remain in their allocated later phases or outside
the database-only scope.
