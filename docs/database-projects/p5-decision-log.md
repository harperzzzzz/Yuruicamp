# P5 source adjudication log

Date: 2026-07-14  
Status: **RESOLVED — no business-only ambiguity remains**

These resolutions were derived from frozen source data, historical repository
evidence and the existing runtime contract. They do not invent missing business
facts and therefore did not require a `BLOCKED` decision.

| ID | Topic | Resolution | Evidence |
| --- | ----- | ---------- | -------- |
| P5-R01 | Five renamed campground inventory locations | `雲海高原→C002`, `溪谷森林→C003`, `松林野營→C004`, `湖畔星空→C005`, `海岸微風→C006` | Pre-integration `camp-001..005` identities in commit `c23388f`, unique minimum-distance rental-stock vectors, and current campground identities all agree |
| P5-R02 | Legacy movement `97:0` | Quarantine with `NO_RENTAL_VARIANT`; do not manufacture a rental SKU | P010 and `v-P010-0` resolve exactly, but P010 is absent from the authoritative rental SKU source |
| P5-R03 | Policy field mismatch | `minLeadDays→advance_days`, `maxStayNights→max_nights`, `lowThresholdRatio 0.3→integer percent 30`; compatibility DTO divides by 100 | `booking-policy.json`, `booking_policies.md`, and `booking-availability.js` |
| P5-R04 | Availability statuses | Normalize `available`, `low`, `full`, `closed`, `out_of_window` as policy child rows | Exhaustive return values of `booking-availability.js#getDayStatus` |
| P5-R05 | Date intervals | Booking nights, blocks and date-range closures use `[start,end)`; weekly `effectiveFrom/effectiveTo` are inclusive | Existing JavaScript runtime contract and 4,745-row SQL/JS regression |
| P5-R06 | Weekly closure bounds | Preserve `effective_from/effective_to` even though the P0 target dictionary omitted them | First-priority `docs/schema.sql`, source JSON, admin calendar editor and runtime availability checks all use them |
| P5-R07 | Historical movement stock effect | Backfill as posted audit history without replaying stock deltas | P2/P3 stock tables are current physical snapshots; replay would double-apply historical events |

P5-R02 is a classified migration outcome, not an unclassified row. Every one of
the 141 legacy items has exactly one store detail, rental detail, conversion or
reasoned quarantine disposition.

