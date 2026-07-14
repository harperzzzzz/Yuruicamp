# P6 source adjudication log

Date: 2026-07-14  
Status: **RESOLVED — no business-only ambiguity**

P6 did not introduce a new business policy. Every disposition below follows an
already approved D-002/D-005/D-009/D-012 decision or a deterministic source
contract.

| ID | Topic | Resolution and evidence | Result |
| --- | --- | --- | --- |
| P6-R01 | Formal review identity | `REV031` matches exactly one P4 row by order `208`, customer `U027`, product `P001`, variant `v-P001-0`; target `order_item_id = 418`. | RESOLVED |
| P6-R02 | Legacy review quarantine | The other 37 rows have no `orderId`; they retain source FKs/snapshots and `NO_ORDER_ID` reason in read-only `legacy_reviews`. No FK is fabricated. | RESOLVED |
| P6-R03 | Official replies | Source has zero reply keys/payload rows. D-009 removes all reply columns and creates no `review_replies`. | RESOLVED |
| P6-R04 | Article heading payload | Source has 12 `heading` blocks and the P6 specification/frontend renderer explicitly supports `text/heading/product`; `heading` uses the text-only branch of the mutual-exclusion check. | RESOLVED |
| P6-R05 | Article publication fields | Legacy `publishedDate` maps to `published_at` at `00:00 Asia/Taipei`; all six seeded articles are `published`. | RESOLVED |
| P6-R06 | Public author | `articles.author` remains the public pen name from source and has no `admin_users` FK, per D-012. | RESOLVED |
| P6-R07 | Movement consumer contract | Admin/report DTOs expose `inventoryDomain` and `variantId`, and derive items only from P5 `inventory_movement_items_view`; the legacy JSON path is an isolated read-only display fallback that never guesses a variant. | RESOLVED |

The `heading` dictionary correction is a deterministic repair of an internal
contract mismatch, not a new business decision. Both the generator and the
generated target dictionary were updated so the result remains reproducible.
