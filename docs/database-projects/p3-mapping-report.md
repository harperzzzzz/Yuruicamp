# P3 rental and location mapping report

Date: 2026-07-14  
Gate status: **PASS — all P3 rental, variant, location and listing mappings are unique**

## Rental identity mapping

| Source                         | Rows | Target mapping                                                  | Unmapped |
| ------------------------------ | ---: | --------------------------------------------------------------- | -------: |
| `rental-skus.json` groups      |   28 | Preserve `R001`–`R028`; `item_id = productId`                   |        0 |
| Rental variants                |   37 | Preserve variant ID in the separate `rental_sku_variants` table |        0 |
| Variant/location stock         |  333 | Preserve C001–C009 as `inventory_locations.id`                  |        0 |
| `camp-equipment.json` listings |   16 | Preserve `equipmentId` as listing ID                            |        0 |

All 28 `productId` values resolve to the P2 `equipment_items` one-to-one ID.
Rental display name, category, brand and image match the corresponding product
source for every row. All 37 legacy variant IDs resolve to the stated product
variant and are retained unchanged in a separate rental-variant namespace; no
name or similarity matching is used.

## Campground and warehouse locations

| Source code   | Meaning                   | P1 location                                   | P3 campground mapping  |
| ------------- | ------------------------- | --------------------------------------------- | ---------------------- |
| `C001`        | Rental warehouse          | `C001` (`rental/main`)                        | Excluded               |
| `C002`–`C009` | Bookable campground stock | Same stable location ID (`rental/campground`) | One row per campground |

Every rental variant has exactly nine physical stock entries covering
C001–C009. The resulting 333 rows total 534 units. Each of the 16 listings
resolves through its campground to exactly one stock row, and its source
`stock` equals that row.

## Minimum-stock preparation

`min-stock.json` contains 252 rental-SKU/location thresholds. Every rental ID
and C001–C009 location resolves uniquely. Expanding the SKU-level threshold to
each rental variant would produce 333 target rows.

The formal `rental_sku_variant_min_stocks` table is allocated to P5 by
`p0-migration-allocation.json`; P3 therefore records the 252 resolved source
rows in `migration.p3_rental_min_stock_source` but does not create or write the
P5 business table.

## Listing reconciliation

All listings have a valid rental group, rental variant and bookable campground.
The 16 IDs, variant IDs, campground IDs, weekday/holiday prices, discounts,
terrain, descriptions and physical stock values can be reconstructed without
unmapped or duplicate targets.
