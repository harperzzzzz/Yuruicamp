# P4 historical financial reconciliation report

Date: 2026-07-14  
Status: **COMPLETE — 0 unresolved differences**

This report closes the P4 financial entry gate using the frozen JSON sources.
The generator is read-only unless explicitly invoked with `--write` to refresh
this report.

## Frozen inputs

| Source | Rows | SHA-256 |
| --- | ---: | --- |
| `data/commerce/orders.json` | 222 | `8fbb07ada2e62642d98384c9722c7b4fbc0c71b74c18e613bca5a7b3fa702b41` |
| `data/commerce/camp-bookings.json` | 90 | `8954e4146efb7f7acedd2a8a2329a608ad7bc3bea124b8594ae97f6aa886afa2` |

## Reconciliation formulas

- Order subtotal: `SUM(items.price * items.quantity)`.
- Order total: `subtotal + shippingFee - discount`.
- Booking zone total: `SUM(selectedZones.subtotal)`.
- Booking rental total: `SUM(selectedRentals.subtotal)`.
- Booking final amount: `zoneTotal + rentalTotal - appliedDiscount`.

## Aggregate evidence

| Dataset | Headers | Detail rows | Stored subtotal | Fees / rental | Discount | Stored final | Differences |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Orders | 222 | 435 | 1821720 | 0 | 0 | 1821720 | 0 |
| Bookings | 90 | 90 zone + 40 rental | 472700 | 43300 | 1432 | 514568 | 0 |

## Difference register

| Domain | ID | Field | Stored | Calculated | Disposition |
| --- | --- | --- | ---: | ---: | --- |
| — | — | — | — | — | No discrepancy |

All 222 orders and 90 bookings reconcile under the approved
P4 formulas. There are no silent corrections and no rows requiring business
adjudication.
