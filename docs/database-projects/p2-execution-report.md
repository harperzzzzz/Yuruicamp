# P2 execution report

Date: 2026-07-14  
Status: **COMPLETE — P3 has not started**

P2 normalizes the store catalog, equipment collections, campground tags and
store inventory. It does not create rental-model targets or implement Spring
Boot catalog services.

## Entry gates

| Gate                           | Result                                                                              |
| ------------------------------ | ----------------------------------------------------------------------------------- |
| P1 complete                    | PASS — P1 execution report is complete                                              |
| D-007                          | PASS — APPROVED                                                                     |
| D-010                          | PASS — APPROVED                                                                     |
| Product/brand/category mapping | PASS — 30 products, 0 unmapped after adding the exact first-party `Yuruicamp` brand |

The detailed mapping is recorded in `docs/database/p2-mapping-report.md`.

## Migration evidence

| Migration                          | Responsibility                                                                                          | SHA-256                                                            |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| `V200__p2_expand_catalog.sql`      | Expand equipment, tag, stock and migration-evidence structures                                          | `8e9708a0d5cd2a284ec1f3a509e524e839c7bcce3895a07e88037c09ae00f207` |
| `V210__p2_backfill_catalog.sql`    | Load frozen product/campground sources and normalize collections and stock                              | `896bb0648cf338356b7fa235cad484c1c50e879df6303be7b941857c1f6dd88f` |
| `V220__p2_constraints_catalog.sql` | Guard reconciliation, install constraints/indexes, remove legacy P2 columns and create the summary view | `44f3e3964f0b2ad6bdcd38014cf1e81aab94d17d4361e7562763845d34e50a83` |

Flyway on a fresh PostgreSQL 18.4 database applied versions
`001,100,110,120,200,210,220` and finished at version `220`. A second Spring
Boot startup validated the history (schema creation plus seven versioned
migrations) and reported the schema up to date with no migration necessary.
`BackendApplicationTests` passed on both successful startups.

The generated V210 content is protected by
`admin/scripts/generate-p2-backfill.cjs`: source drift fails the check and must
be handled by a new forward migration after V210 is applied.

## Backfill reconciliation

| P2 dataset                              | Rows / quantity |
| --------------------------------------- | --------------: |
| Products                                |              30 |
| Equipment items                         |              30 |
| Product variants                        |              39 |
| Equipment images                        |              90 |
| Equipment tags                          |              35 |
| Equipment interest tags                 |              30 |
| Equipment specifications                |              19 |
| Store inventory rows                    |             156 |
| Store on-hand quantity                  |             401 |
| Environment tag definitions / relations |          5 / 19 |
| Facility tag definitions / relations    |          7 / 24 |

All product IDs are preserved and also serve as their one-to-one equipment
IDs. Every store stock key maps exactly to `main` or `branch-001` through
`branch-003`. No name-similarity matching is used.

`migration.p2_product_source` and
`migration.p2_campground_tag_source` retain the frozen source payload only as
migration/validation evidence. V220 checks the normalized copy before removing
the public legacy JSONB, display and cached stock columns.

`product_stock_summary.total_reserved` is `0` in P2 because the authoritative
reservation ledger belongs to P4. P4 must replace the view definition when the
ledger is created; P2 does not invent active reservations for historical
orders.

## Verification gates

| Gate                             | Result                                                                                                            |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `p2-structure.sql`               | PASS — 0 issues; required relations, named constraints, FK indexes, legacy-column removal and view types verified |
| `p2-data.sql`                    | PASS — 0 issues; all source/target counts, FKs, values and stock totals reconcile                                 |
| `p2-compatibility.sql`           | PASS — 0 differences across 30 product DTOs, variants, stock and campground tags                                  |
| `p2-business-rules.sql`          | PASS — negative prices/stock and duplicate mappings/SKUs rejected; RESTRICT/CASCADE behavior verified             |
| Flyway second startup            | PASS — schema at `v220`, no migration necessary                                                                   |
| Spring Boot / Hibernate validate | PASS — 1 test, 0 failures/errors on both successful startups                                                      |
| P0/P1 source guards              | PASS — P0 baseline/dictionary/audit and P1/P2 generators match                                                    |
| Frontend build / smoke           | PASS — existing non-module script warnings only                                                                   |
| P3 scope guard                   | PASS — 0 P3 target objects                                                                                        |
| Source mutation guard            | PASS — `data/**` unchanged                                                                                        |

P2 intentionally does not implement API bridge-write, feature flags or Spring
Boot CRUD. Those runtime responsibilities remain outside the database-only
scope defined by `docs/database/agent.md`.
