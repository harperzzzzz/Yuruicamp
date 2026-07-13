# equipment_items
# products
# products_variants
# rental_skus
# rental_sku_variants
# rental_sku_variant_stocks
# rental_listings
# booking_selected_rentals

## 大改：共用裝備主檔 + 販售 / 租借分離

原本 `rental_skus` 和 `products` 直接關聯，會讓租借資料依賴販售商品，也會重複保存 `name`、`category`、`brand`、`image`。

改成抽出 `equipment_items` 作為裝備主檔：

* `equipment_items`：裝備身份與顯示資料的唯一來源。
* `products`：販售商品，只處理價格、販售狀態、販售 SKU 與販售庫存。
* `rental_skus`：租借商品，只處理租借狀態、租借 SKU 與租借庫存。

支援三種情境：

* 只賣不租：`equipment_items` 有一筆，`products` 有一筆，`rental_skus` 沒有。
* 只租不賣：`equipment_items` 有一筆，`rental_skus` 有一筆，`products` 沒有。
* 又賣又租：`equipment_items` 有一筆，`products` 和 `rental_skus` 各一筆。

關係：

```text
equipment_items
  ├─ equipment_images
  ├─ equipment_tags
  ├─ equipment_interest_tags
  ├─ equipment_specifications
  ├─ products
  │    └─ product_variants
  │         └─ 販售庫存
  └─ rental_skus
       └─ rental_sku_variants
            └─ rental_sku_variant_stocks
                 └─ rental_listings
                      └─ booking_selected_rentals
```


1. equipment_items：裝備主檔
共用身份資料，例如名稱、分類、品牌、主圖、描述。
id
name
category_id
brand_id
image
description
created_at
updated_at

* `name`、`category`、`brand`、`image` 不再重複放在 `products` 或 `rental_skus`。
* `category_id`、`brand_id` 可先對應既有分類 / 品牌主檔；若尚未建立分類表，可暫時保留文字欄位，但權威仍在 `equipment_items`。
* 多張圖、標籤、興趣標籤、規格不放 JSONB，拆到子表，避免 1NF 問題。
----
CREATE TABLE equipment_items (
  id                VARCHAR(32) PRIMARY KEY,
  name              VARCHAR(200) NOT NULL,

  category_id       VARCHAR(32),
  brand_id          VARCHAR(32),

  image             TEXT,
  description       TEXT,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
----


2. equipment_images：裝備圖片

item_id
sort_order
url
alt_text

* 多張圖片與排序拆表保存。
* `equipment_items.image` 可保留主圖快取；完整圖片列表以此表為準。
----
CREATE TABLE equipment_images (
  item_id           VARCHAR(32) NOT NULL
                    REFERENCES equipment_items(id)
                    ON DELETE CASCADE,

  sort_order        INTEGER NOT NULL DEFAULT 0,
  url               TEXT NOT NULL,
  alt_text          TEXT,

  PRIMARY KEY (item_id, sort_order)
);

CREATE INDEX idx_equipment_images_item_order
  ON equipment_images(item_id, sort_order);
----


3. equipment_tags：裝備標籤

item_id
tag

* 例如「帳篷」、「Coleman」、「新手推薦」。
----
CREATE TABLE equipment_tags (
  item_id           VARCHAR(32) NOT NULL
                    REFERENCES equipment_items(id)
                    ON DELETE CASCADE,

  tag               VARCHAR(64) NOT NULL,

  PRIMARY KEY (item_id, tag)
);

CREATE INDEX idx_equipment_tags_tag
  ON equipment_tags(tag);
----


4. equipment_interest_tags：興趣標籤

item_id
interest_tag

* 例如 tent / safety / cooking，用於導購、推薦、問卷匹配。
----
CREATE TABLE equipment_interest_tags (
  item_id           VARCHAR(32) NOT NULL
                    REFERENCES equipment_items(id)
                    ON DELETE CASCADE,

  interest_tag      VARCHAR(64) NOT NULL,

  PRIMARY KEY (item_id, interest_tag)
);

CREATE INDEX idx_equipment_interest_tags_tag
  ON equipment_interest_tags(interest_tag);
----


5. equipment_specifications：裝備規格

item_id
spec_key
spec_value

* 例如 weight、capacity、material、waterproof。
* 若之後需要數值篩選，可再加 `specification_definitions` 管理型別與單位。
----
CREATE TABLE equipment_specifications (
  item_id           VARCHAR(32) NOT NULL
                    REFERENCES equipment_items(id)
                    ON DELETE CASCADE,

  spec_key          VARCHAR(64) NOT NULL,
  spec_value        TEXT NOT NULL,

  PRIMARY KEY (item_id, spec_key)
);

CREATE INDEX idx_equipment_specifications_key
  ON equipment_specifications(spec_key);
----


6. products：販售商品
拿這個裝備去賣
id
item_id
price
status
total_stock 商品總庫存快取
created_at
updated_at

* 移除原本的 `rental_id` 與 `rental_enabled`。
* 移除 `name`、`category`、`brand`、`image`、`images`、`description`、`specifications`、`tags`，顯示資料統一從 `equipment_items` 取得。
* `products` 只代表「這個裝備是否作為商城商品販售」。
----
CREATE TABLE products (
  id                VARCHAR(32) PRIMARY KEY,

  item_id           VARCHAR(32) NOT NULL
                    REFERENCES equipment_items(id)
                    ON DELETE CASCADE,

  price             NUMERIC(12, 2) NOT NULL DEFAULT 0
                    CHECK (price >= 0),

  status            product_status NOT NULL DEFAULT 'active',

  -- 販售庫存的衍生快取，不是庫存唯一來源
  total_stock       INTEGER
                    CHECK (total_stock IS NULL OR total_stock >= 0),

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- 一個裝備通常只對應一個販售商品
  UNIQUE (item_id)
);

CREATE INDEX idx_products_item
  ON products(item_id);
----


7. product_variants

id 販售 SKU 主鍵
product_id
`sku 對外或內部 SKU 編號，可以合併但如果 sku 未來可能改名則不建議`
color
size
`label 前端解決`
price
branch_stock 各分店庫存 JSONB

* 只處理販售 products 的 SKU。
----
CREATE TABLE product_variants (
  id                VARCHAR(64) PRIMARY KEY,

  product_id        VARCHAR(32) NOT NULL
                    REFERENCES products(id)
                    ON DELETE CASCADE,

  sku               VARCHAR(64) NOT NULL,
  color             VARCHAR(64),
  size              VARCHAR(64),
  label             VARCHAR(128),

  price             NUMERIC(12, 2)
                    CHECK (price IS NULL OR price >= 0),

  `branch_stock      JSONB, product_variants.md 有進行拆表`

  UNIQUE (product_id, sku)
);

CREATE INDEX idx_product_variants_product
  ON product_variants(product_id);
----


8. `rental_skus 看要不要改名`
拿這個裝備去租
id
item_id
status 租借商品狀態
created_at
updated_at

* `rental_skus` 不再直接關聯 `products`，避免租借依賴販售商品。
* 租借商品的 `name`、`category`、`brand`、`image` 從 `equipment_items` 取得。
* `rental_skus` 只代表「這個裝備是否可租借」與租借庫存群組。
----
CREATE TABLE rental_skus (
  id                VARCHAR(32) PRIMARY KEY,

  item_id           VARCHAR(32) NOT NULL
                    REFERENCES equipment_items(id)
                    ON DELETE CASCADE,

  status            VARCHAR(32) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'inactive')),

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- 一個裝備通常只對應一個租借主檔
  UNIQUE (item_id)
);

CREATE INDEX idx_rental_skus_item
  ON rental_skus(item_id);
----


9. rental_sku_variants

id
rental_sku_id
sku
color
size
`label 一樣前端處理`
image
`description 變體租借說明，好多餘`

* 租借商品自己的變體，不再使用 product_variants。
* `image` 可作變體專用圖；沒有則使用 `equipment_items.image`。
----
CREATE TABLE rental_sku_variants (
  id                VARCHAR(64) PRIMARY KEY,

  rental_sku_id     VARCHAR(32) NOT NULL
                    REFERENCES rental_skus(id)
                    ON DELETE CASCADE,

  sku               VARCHAR(64) NOT NULL,
  color             VARCHAR(64),
  size              VARCHAR(64),
  label             VARCHAR(128),
  image             TEXT,
  description       TEXT,

  UNIQUE (rental_sku_id, sku)
);

CREATE INDEX idx_rental_sku_variants_rental_sku
  ON rental_sku_variants(rental_sku_id);
----


10. rental_sku_variant_stocks
id
rental_sku_variant_id
`campground_id 庫存所在地，倉庫和營地會混在一起`
quantity

* 庫存指向 rental_sku_variants。
* 租借庫存只放這裡，`rental_listings.stock` 不再作為手動維護欄位。
----
CREATE TABLE rental_sku_variant_stocks (
  id                    BIGSERIAL PRIMARY KEY,

  rental_sku_variant_id  VARCHAR(64) NOT NULL
                         REFERENCES rental_sku_variants(id)
                         ON DELETE CASCADE,

  location_id VARCHAR(32) NOT NULL 
                        REFERENCES inventory_locations(id),
  quantity              INTEGER NOT NULL DEFAULT 0
                         CHECK (quantity >= 0),

  UNIQUE (rental_sku_variant_id, campground_id)
);

CREATE INDEX idx_rental_variant_stock_lookup
  ON rental_sku_variant_stocks(
    rental_sku_variant_id,
    campground_id
  );
----



11. rental_listings

id
rental_sku_id 租借商品主檔
rental_sku_variant_id
campground_id 提供租借的營區
terrain_tag 地形標籤
`description 目前沒有`
price_per_day_weekday
price_per_day_holiday
discount

* listing 指向租借變體，而不是販售變體。
* `name`、`image_url`、`color`、`size`、`spec_label` 都可由 `equipment_items` + `rental_sku_variants` 查出，不建議重複保存。
* 若需要下單當下快照，放在 `booking_selected_rentals`。
----
CREATE TABLE rental_listings (
  id                    VARCHAR(32) PRIMARY KEY,

  rental_sku_id          VARCHAR(32) NOT NULL
                         REFERENCES rental_skus(id),

  rental_sku_variant_id  VARCHAR(64) NOT NULL
                         REFERENCES rental_sku_variants(id),

  location_id VARCHAR(32) NOT NULL REFERENCES inventory_locations(id),

  terrain_tag           VARCHAR(128),
  description           TEXT,

  price_per_day_weekday NUMERIC(12, 2) NOT NULL DEFAULT 0
                         CHECK (price_per_day_weekday >= 0),

  price_per_day_holiday NUMERIC(12, 2) NOT NULL DEFAULT 0
                         CHECK (price_per_day_holiday >= 0),

  discount              NUMERIC(12, 2) NOT NULL DEFAULT 0
                         CHECK (discount >= 0),

  UNIQUE (campground_id, rental_sku_variant_id)
);
----

* rental_listings.stock 不存，改用 VIEW/JOIN 產生。
* stock = rental_sku_variant_stocks.quantity。
* 顯示用欄位從 `equipment_items` 與 `rental_sku_variants` join。

包成 View：
---
CREATE VIEW rental_listing_view AS
SELECT
  rl.*,
  ei.name,
  ei.category_id,
  ei.brand_id,
  COALESCE(rsv.image, ei.image) AS image_url,
  rsv.sku,
  rsv.color,
  rsv.size,
  rsv.label AS spec_label,
  rs.quantity AS stock
FROM rental_listings rl
JOIN rental_skus rsku
  ON rsku.id = rl.rental_sku_id
JOIN equipment_items ei
  ON ei.id = rsku.item_id
JOIN rental_sku_variants rsv
  ON rsv.id = rl.rental_sku_variant_id
JOIN rental_sku_variant_stocks rs
  ON rs.rental_sku_variant_id = rl.rental_sku_variant_id
 AND rs.location_id = rl.location_id;
---


12. booking_selected_rentals

id
booking_id
rental_listing_id
rental_sku_id
rental_sku_variant_id
item_id
`sku 快照`
`name 快照`
`spec_label 快照`
quantity
unit_price 當時單價
subtotal

* 預約明細指向租借 listing 與租借變體。
* `item_id` 保留裝備主檔關聯。
* `sku`、`name`、`spec_label` 是下單當下快照，合理重複保存。
----
CREATE TABLE booking_selected_rentals (
  id                    BIGSERIAL PRIMARY KEY,

  booking_id            BIGINT NOT NULL
                        REFERENCES bookings(id)
                        ON DELETE CASCADE,

  rental_listing_id     VARCHAR(32) NOT NULL
                        REFERENCES rental_listings(id),

  rental_sku_id         VARCHAR(32) NOT NULL
                        REFERENCES rental_skus(id),

  rental_sku_variant_id VARCHAR(64) NOT NULL
                        REFERENCES rental_sku_variants(id),

  item_id               VARCHAR(32) NOT NULL
                        REFERENCES equipment_items(id),

  sku                   VARCHAR(64),
  name                  VARCHAR(200),
  spec_label            VARCHAR(128),

  quantity              INTEGER NOT NULL
                        CHECK (quantity > 0),

  unit_price             NUMERIC(12, 2) NOT NULL DEFAULT 0
                         CHECK (unit_price >= 0),

  subtotal              NUMERIC(12, 2) NOT NULL DEFAULT 0
                        CHECK (subtotal >= 0)
);
----
