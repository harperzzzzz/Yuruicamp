# P6 mapping and reconciliation report

Date: 2026-07-14  
Status: **COMPLETE**

## Review mapping

| Source disposition | Rows | Target | Authority |
| --- | ---: | --- | --- |
| Exact purchased item | 1 | `reviews` | `REV031 → order_items.id 418` |
| Missing `orderId` | 37 | `legacy_reviews` | `NO_ORDER_ID`; read-only evidence |
| Ambiguous match | 0 | — | No business adjudication required |
| Unclassified/unmigrated | 0 | — | Exactly-one target verified |

Both formal and legacy source photo arrays are empty, so the normalized photo
tables correctly contain zero rows. The migration and validators still expand
and reconcile array order/URL for future non-empty payloads.

## Article mapping

| Source | Rows | Target |
| --- | ---: | --- |
| Articles | 6 | `articles` |
| Tags | 18 | `article_tags` |
| Content blocks | 41 | `article_content_blocks` |
| Text / heading / product blocks | 18 / 12 / 11 | Mutually exclusive text or product payload |
| Related products | 16 | `article_related_products` with unique order |

All tag sets, ordered content blocks and ordered related products reconcile to
the frozen JSON source with zero differences. Author values remain public pen
names and do not reference an administrator account.

## Consumer mapping

`review_dto_view` reconstructs relationship and display fields from
`order_items`, `orders`, `customers`, normalized photos and legacy snapshots;
it adds `verifiedPurchase` and exposes no reply field. `article_dto_view`
reconstructs the existing article JSON contract. `inventory_movement_dto_view`
contains 171 headers and 109 concrete store/rental items, and reads P5
`inventory_movement_items_view` rather than a shared physical detail table.
