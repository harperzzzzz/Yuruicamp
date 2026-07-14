# P4 source and mapping report

Date: 2026-07-14  
Status: **APPROVED — all four P4 decision topics resolved**

## Source inventory

| Source | Headers | Details / events |
| --- | ---: | ---: |
| Orders | 222 | 435 items; 1018 history events |
| Bookings | 90 | 90 zones; 40 rentals; 249 history events |
| Coupons | 7 | legacy cached used total 157 |

## Deterministic reconciliation

- Header/detail financial differences: orders 0, bookings 0.
- Missing or conflicting customer/product/variant/zone/listing references: 0.
- Order history actions (8): 已付款, 已出貨, 已完成, 已退貨, 待付款, 待出貨, 訂單產生, 貨到付款.
- Booking history actions (8): 已付款, 已取消（原因：行程變更）, 已取消（原因：遇颱風警報）, 已取消（原因：顧客臨時有事）, 已完成, 已確認預約, 已退款, 預約單已送出.
- Existing product reservations to backfill: 0, per the approved P4 rule for historical orders.
- Rental reservation candidates: 40; each resolves to one P3 listing, rental variant and campground location.

## Official calendar evidence

The target calendar source is the Directorate-General of Personnel
Administration 2026 government work calendar, revision announced 2025-10-02.
P4 treats Saturdays, Sundays and the published days off as holidays. It does
not infer official calendar dates from the mock booking totals.

- Booking source day-count differences: 65.
- Examples (booking: source weekday/holiday -> official): 2: 0/0 -> 1/0, 4: 0/1 -> 2/1, 5: 1/1 -> 0/2, 6: 0/2 -> 1/1, 7: 1/0 -> 2/0, 8: 0/1 -> 1/2, 9: 0/1 -> 1/0, 10: 0/0 -> 1/1, 11: 0/1 -> 1/1, 12: 2/3 -> 1/2, 13: 2/2 -> 1/1, 14: 2/1 -> 3/0.

## Historical price snapshot gaps

The booking headers reconcile exactly with their stored detail subtotals, but
the JSON does not retain the historical weekday/holiday prices used to create
those subtotals. Reusing current master prices together with the official
calendar would change historical amounts:

- Zone lines that differ: 59 of 90.
- Rental lines that differ: 35 of 40.
- Zone examples (booking/zone: stored -> recalculated): 2/Z009: 1700 -> 1100, 3/Z010: 2200 -> 1500, 4/Z005: 30000 -> 24000, 6/Z002: 3600 -> 3000, 7/Z005: 10000 -> 7000, 8/Z009: 5100 -> 4500, 10/Z004: 2600 -> 2200, 11/Z005: 20000 -> 17000, 12/Z001: 6000 -> 8000, 13/Z003: 2400 -> 2000, 14/Z002: 5400 -> 3600, 15/Z012: 2850 -> 3850.
- Rental examples (booking/listing: stored -> recalculated): 1/E022: 1800 -> 1700, 5/E025: 600 -> 1800, 5/E023: 1000 -> 1800, 8/E021: 1800 -> 2100, 9/E013: 3200 -> 600, 9/E011: 300 -> 400, 10/E015: 500 -> 850, 12/E010: 1800 -> 4000, 13/E016: 1600 -> 850, 16/E021: 3200 -> 1500, 18/E017: 300 -> 800, 20/E019: 600 -> 1200.

## Other missing snapshots

- Orders contain the historical buyer name and shipping address, but not buyer
  email, recipient name or shipping phone. Current customer data can fill them
  deterministically, but cannot prove the values were true when the order was
  placed (666 field fallbacks).
- Coupons do not contain the target display name. Using the stable code as the
  name is deterministic but is a fallback, not a recovered historical value.

## Rental reservation capacity

- Over-capacity keys under direct status mapping: 28.
- Terminal reservations that can be retained: 18.
- Future capacity-valid active reservations: 3.
- Stale active rows at the 2026-07-14 cutoff: 17.
- Future active conflicts after stable first-in allocation: 2.
- Required reconciliation: 21 target reservations + 19 quarantine rows = 40 source rental lines.

## Approved adjudication

1. All 222 orders lack historical buyer email, recipient name and shipping phone snapshots.
2. All 7 coupons lack the target name field.
3. 65 bookings disagree with the official 2026 calendar; 59 zone lines and 35 rental lines cannot preserve their stored subtotal using current master prices plus official day counts.
4. Directly activating every pending/confirmed rental creates 28 over-capacity variant/location/date keys; 19 of 40 rental lines require explicit quarantine under the recommended cutoff/allocation policy.

Recommended migration policy: preserve all stored historical totals and use the
official calendar counts. For an unreconstructable line, choose non-negative
cent-valued weekday/holiday prices (and rental discount) that reproduce the
stored subtotal exactly while minimizing deviation from the current master
price vector, with a stable tie-breaker; record every fallback in migration
evidence. For missing order snapshots use customer email/phone and buyerName as
recipient; for coupon name use the stable coupon code. This policy requires
explicit approval because the absent historical values cannot be uniquely
recovered. The user approved all recommended P4 decisions on 2026-07-14.
