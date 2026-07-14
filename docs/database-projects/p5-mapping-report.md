# P5 mapping report

Date: 2026-07-14  
Status: **COMPLETE**

## Source reconciliation

| Source | Source rows | P5 result |
| ------ | ----------: | --------- |
| Booking policy | 1 | 1 scalar policy, 3 occupying statuses, 5 availability statuses |
| Zone blocks | 2 | 2 normalized blocks |
| Campground closures | 2 | 1 date range and 1 bounded weekly closure |
| Store minimum-stock target/location pairs | 120 | 156 product-variant/location rows |
| Rental minimum-stock target/location pairs | 252 | 333 rental-variant/location rows |
| Legacy movement headers | 100 | 171 single-domain audit headers |
| Legacy movement items | 141 | 65 store details, 44 rental details, 31 conversions, 1 quarantine |

The 100 legacy headers contain 25 headers that require more than one migration
classification. All 32 store-to-camp rows were classified: 31 have a valid
rental destination variant and become conversions; movement `97:0` is the sole
approved quarantine because no rental variant exists.

## Movement resolution rules

1. Product variants are resolved only when `productId` exists and the complete
   `productName（variant label）` snapshot matches exactly one variant.
2. Store and rental domains come from authoritative inventory locations, not
   from product category or name.
3. Same-domain items are grouped only when legacy header, domain, movement type,
   source and destination are all identical.
4. Every store-to-rental item creates one store-out header, one rental-in header
   and one idempotent `inventory_conversions` row.
5. `進貨` is a null physical source and `損耗` is a null physical destination.
6. Historical posted headers do not update P2/P3 current stock snapshots.

The machine-readable evidence and source hashes are in
`docs/database/p5-source-audit.json`; generation is enforced by
`admin/scripts/audit-p5-sources.cjs` and
`admin/scripts/generate-p5-backfill.cjs`.

