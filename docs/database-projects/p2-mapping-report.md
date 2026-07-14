# P2 product, brand and category mapping report

Date: 2026-07-14  
Source: `data/catalog/products.json` and P1 master data  
Gate status: **PASS — every P2 product has one exact brand and category mapping**

## Product identity mapping

All 30 source product IDs are unique and are retained unchanged. The same stable
ID is used for the corresponding `equipment_items.id`, and `products.item_id`
references it. This produces 30 explicit one-to-one mappings without matching
by display name or similarity.

## Brand mapping

| Source brand | Products | Target brand ID   | Result                                       |
| ------------ | -------: | ----------------- | -------------------------------------------- |
| `Coleman`    |        2 | `brand-004`       | Existing P1 master, exact name               |
| `MSR`        |        1 | `brand-003`       | Existing P1 master, exact name               |
| `Snow Peak`  |        2 | `brand-001`       | Existing P1 master, exact name               |
| `Yuruicamp`  |       25 | `brand-yuruicamp` | Exact first-party source brand added by V210 |

`Yuruicamp` is present verbatim on 25 products but is not part of the 12
marketing-logo brands seeded in P1. V210 therefore adds it as its own
first-party brand; it is not aliased to an unrelated manufacturer. After this
addition the unmapped brand count is `0`.

## Category mapping

| Source category | Products | P1 category code | Result     |
| --------------- | -------: | ---------------- | ---------- |
| `帳篷`          |        5 | `tent`           | Exact name |
| `睡袋`          |        3 | `sleeping-bag`   | Exact name |
| `炊具`          |        4 | `cookware`       | Exact name |
| `燈具`          |        2 | `lighting`       | Exact name |
| `背包`          |        2 | `backpack`       | Exact name |
| `其他`          |       14 | `other`          | Exact name |

All six values already exist in `product_categories`; the unmapped category
count is `0`. No category is inferred from product names.

## Reconciliation baseline

| Source collection                       | Expected rows |
| --------------------------------------- | ------------: |
| Products / equipment items              |            30 |
| Product variants                        |            39 |
| Equipment images                        |            90 |
| Equipment tags                          |            35 |
| Equipment interest tags                 |            30 |
| Equipment specifications                |            19 |
| Store inventory rows                    |           156 |
| Store on-hand quantity                  |           401 |
| Environment tag definitions / relations |        5 / 19 |
| Facility tag definitions / relations    |        7 / 24 |

The P2 migration must fail before contract if any product, brand, category,
store location, collection value or stock quantity cannot be reconciled.
