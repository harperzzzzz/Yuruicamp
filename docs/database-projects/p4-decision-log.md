# P4 migration decision log

Date: 2026-07-14  
Status: **APPROVED — 2026-07-14**

The P4 source audit found no orphan references and no header/detail amount
differences. The following historical snapshot values are absent or conflict
with the authoritative calendar and therefore cannot be uniquely recovered.

## P4-D01: missing order contact snapshots

- Evidence: all 222 orders contain `buyerName` and `address`, but none contains
  buyer email, recipient name or shipping phone.
- Recommended decision: preserve `buyerName` and `address`; backfill
  `buyer_email_snapshot` and `shipping_phone_snapshot` from the referenced
  customer at migration time, and use `buyerName` for
  `recipient_name_snapshot`.
- Control: write three `migration.p4_snapshot_fallbacks` rows per order so the
  fallback is never represented as an original historical value.
- Status: **APPROVED**.

## P4-D02: missing coupon display names

- Evidence: all 7 coupons have a stable unique `code` but no `name` field.
- Recommended decision: use `code` as `name` during P4 backfill.
- Control: write one `migration.p4_snapshot_fallbacks` row per coupon.
- Status: **APPROVED**.

## P4-D03: historical booking calendar and price snapshots

- Evidence: 65 of 90 bookings disagree with the official 2026 calendar;
  current master prices plus official counts change 59 of 90 zone subtotals
  and 35 of 40 rental subtotals. The stored booking headers nevertheless match
  their stored detail subtotals exactly.
- Required invariant: `calendar_dates` follows the official DGPA 2026 calendar;
  booking day counts equal `[check_in, check_out)`; historical stored totals are
  not silently changed.
- Recommended decision: use official weekday/holiday counts. When current
  master price snapshots do not reproduce a stored line subtotal, select
  non-negative cent-valued weekday/holiday prices (and rental discount) that
  reproduce it exactly while minimizing deviation from the current master
  price vector. Resolve ties lexicographically and record the source/current,
  chosen and stored/calculated values in migration evidence.
- Rejected shortcut: equal blended prices without an exact-cent proof, because
  rounding can change the historical total.
- Status: **APPROVED**.

## P4-D04: legacy active rental reservations exceed physical stock

- Evidence: treating every `pending`/`confirmed` booking as active produces 28
  over-capacity variant/location/date keys. At the 2026-07-14 migration cutoff,
  the 40 rental lines consist of 18 already-terminal rows, 17 stale active
  rows whose checkout has passed, and 5 future active candidates. Allocating
  future candidates by `submittedAt`, booking ID and line ordinal accepts 3
  and leaves 2 conflicts.
- Recommended decision: create the 18 terminal reservations and the 3
  capacity-valid future active reservations. Put the 17 stale rows and 2
  future conflicts in `migration.p4_rental_reservation_quarantine` with exact
  reason codes; do not increase P3 physical stock and do not create an active
  reservation that makes availability negative.
- Reconciliation invariant: target reservations plus quarantine rows must equal
  all 40 source rental lines. Quarantine is migration evidence, not an active
  inventory claim.
- Status: **APPROVED**.

Approval phrase: `批准 P4 決策紀錄全部建議方案`.

Approval evidence: the user supplied the approval phrase on 2026-07-14.
