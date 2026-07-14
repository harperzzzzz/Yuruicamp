# P4 execution report

Date: 2026-07-14  
Status: **COMPLETE — P5 has not started**

P4 replaces the legacy order, coupon and booking transaction structures with
normalized snapshot tables, structured histories, an authoritative 2026
calendar, coupon and customer summary views, and separate product/rental stock
reservation ledgers. The pre-P4 physical tables remain in the `migration`
schema as read-only audit evidence.

## Entry gates and decisions

| Gate                                      | Result                                                             |
| ----------------------------------------- | ------------------------------------------------------------------ |
| P1 through P3 complete                    | PASS — all three execution reports are complete                    |
| D-002, D-003, D-004, D-010, D-011         | PASS — APPROVED                                                    |
| Historical financial report               | PASS — 222 orders and 90 bookings, 0 unresolved amount differences |
| Transaction FK and rental-variant mapping | PASS — 0 missing, ambiguous or conflicting references              |
| P4-D01 through P4-D04                     | PASS — all recommended policies approved on 2026-07-14             |

The approved P4-only adjudications are recorded in
`docs/database/p4-decision-log.md`. They authorize customer-sourced missing
order contact snapshots, coupon-code display-name fallback, official-calendar
day counts with exact-cent price reconstruction, and the 21-target/19-
quarantine rental reservation disposition. The authoritative calendar input is
the [DGPA 2026 government office calendar](https://www.dgpa.gov.tw/information?pid=12685&uid=55),
whose revision was announced on 2025-10-02.

## Migration evidence

| Migration                               | Responsibility                                                                                                           | SHA-256                                                            |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------ |
| `V400__p4_expand_transactions.sql`      | Create P4 staging transaction, calendar, ledger and migration-evidence structures                                        | `1a6b7f5de80d2b6f63e314dcd09347c0802575726b04e9c02b85e57d983c3691` |
| `V410__p4_backfill_transactions.sql`    | Load frozen sources, normalized snapshots, exact-cent pricing, histories, calendar and approved reservation dispositions | `ce248006443a4ea651f29c7c8f0e5ab7ebb8a6eb0f3afcc6ed4d341c5494b004` |
| `V420__p4_constraints_transactions.sql` | Reconcile, install constraints/indexes, switch legacy tables and create authoritative derived views                      | `1049cbc096e2956b8db55890767cc83e5fb61fdb6b4af40ec00252817b3d73e0` |

Flyway applied `V001` through `V420` transactionally on a fresh PostgreSQL
18.4 database. A second Spring Boot startup validated all checksums, reported
schema version `420` as up to date with no migration necessary, and passed
`BackendApplicationTests` with Hibernate `ddl-auto=validate`.

The rental composite-FK name in the target dictionary exceeds PostgreSQL's
63-byte identifier limit. PostgreSQL deterministically stores the first 63
bytes (`fk_rental_stock_reservations_booking_selected_rental_id_rental_`);
the structure validator explicitly verifies that effective name and the full
composite FK definition.

## Backfill reconciliation

| P4 dataset                                               |                                  Rows / result |
| -------------------------------------------------------- | ---------------------------------------------: |
| Orders / items / history                                 |                              222 / 435 / 1,018 |
| Coupons / reconstructed order coupon usage / adjustments |                                      7 / 0 / 0 |
| Calendar dates                                           |        365 (`2026-01-01` through `2026-12-31`) |
| Bookings / zones / rentals / history                     |                             90 / 90 / 40 / 249 |
| Order contact fallback evidence                          |                                            666 |
| Coupon-name fallback evidence                            |                                              7 |
| Official day-count fallbacks                             |                        65 (25 already matched) |
| Zone price fallbacks                                     |                        59 (31 already matched) |
| Rental price fallbacks                                   |                         35 (5 already matched) |
| Historical product reservations                          |                                              0 |
| Rental reservations                                      |         21: 3 active, 14 fulfilled, 4 released |
| Rental quarantine                                        | 19: 17 stale-past, 2 future-capacity conflicts |

All normalized order and booking detail formulas reproduce their stored
historical totals exactly. Aggregate order subtotal/final total is
`1,821,720.00`; booking zone/rental/final totals are `472,700.00`, `43,300.00`
and `514,568.00`. No source amount was silently changed.

`product_stock_summary` now subtracts active product reservations from
physical stock. `coupon_usage_stats` derives recognized use from paid active
orders plus the idempotent adjustment ledger without clamping. Customer
spending and tier views derive D-001's `explorer`, `guide` and `master` values
without writing them back to customer rows.

## Verification gates

| Gate                             | Result                                                                                                           |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `p4-structure.sql`               | PASS — 0 issues; tables/views, named constraints, FK indexes, legacy audit and P5 scope verified                 |
| `p4-data.sql`                    | PASS — 0 issues; all source/target counts, FK resolution and 40 rental dispositions reconcile                    |
| `p4-financials.sql`              | PASS — 0 issues; order, booking, calendar, coupon, customer and stock derivations match                          |
| `p4-compatibility.sql`           | PASS — 0 differences across normalized order/booking/coupon DTO fields and histories                             |
| `p4-business-rules.sql`          | PASS — tier boundaries, formulas, delete policies, ledger state, idempotency and intervals passed rollback tests |
| Flyway fresh migration           | PASS — V001 through V420 applied on PostgreSQL 18.4                                                              |
| Flyway second startup            | PASS — schema at v420, checksums valid, no migration necessary                                                   |
| Spring Boot / Hibernate validate | PASS — 1 test, 0 failures/errors on both startups                                                                |
| P0-P4 source guards              | PASS — baseline, dictionary, audits and all four backfill generators match                                       |
| JSON read-only checks            | PASS — FK/contract, listings, articles and phase-1 normalization report 0 differences                            |
| Frontend build / smoke           | PASS — Vite build and smoke exit 0; existing non-module-script warnings only                                     |
| P5 scope guard                   | PASS — no `V5*.sql` and no P5-only target objects                                                                |
| Source mutation guard            | PASS — `data/**` unchanged                                                                                       |

P4 does not implement Spring Boot transaction CRUD, runtime reservation
locking, scheduled expiration, inventory posting, policy normalization or P5
minimum-stock/movement structures. Those remain assigned to the application
layer or P5. No P5 migration or target was created during this phase.
