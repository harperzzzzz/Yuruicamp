# products
# products_variants
# rental_sku
# rental_sku_variant_stocks
# rental_listings
# booking_selected_rentals

## 大改，rental_skus 和products 變為可選關係而不是絕對的FK ，可以獨立rental 也可以有共通裝備

products
  └─ product_variants
       └─ 販售庫存

products
  └─ optional rental_skus
       └─ rental_sku_variants
            └─ rental_sku_variant_stocks
                 └─ rental_listings
                      └─ booking_selected_rentals


1. products：商品主檔
id
name
category
brand
interest_tags
price
status
image
images
description
specifications 詳細規格，防水係數、材質...
tags 
total_stock 商品總庫存快取
created_at
updated_at

* 移除原本的 rental_id 與 rental_enabled，租借關聯改由 rental_skus.product_id 管理。
----
CREATE TABLE products (
  id                VARCHAR(32) PRIMARY KEY,
  name              VARCHAR(200) NOT NULL,
  category          VARCHAR(64),
  brand             VARCHAR(64),
  interest_tags     JSONB,
  price             NUMERIC(12, 2) NOT NULL DEFAULT 0
                    CHECK (price >= 0),
  status            product_status NOT NULL DEFAULT 'active',
  image             TEXT,
  images            JSONB,
  description       TEXT,
  specifications    JSONB,
  tags              JSONB,

  -- 販售庫存的衍生快取，不是庫存唯一來源
  total_stock       INTEGER
                    CHECK (total_stock IS NULL OR total_stock >= 0),

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
----


2. product_variants
id 販售 SKU 主鍵
product_id
`sku 對外或內部 SKU 編號，可以合併但如果sku 未來可能改名則不建議`
color
size
`label 前端解決`
price
branch_stock 各分店庫存JSONB

* 只處理販售products 的SKU
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
  branch_stock      JSONB,

  UNIQUE (product_id, sku)
);

CREATE INDEX idx_product_variants_product
  ON product_variants(product_id);
----


3. `rental_skus 看要不要改名`
id
products_id
name
category
`brand 品牌 目前沒有`
image
`description 目前沒有描述`
status 租借商品狀態
created_at
updated_at

* 可以獨立存在，也可以選擇性連到 products。
----
CREATE TABLE rental_skus (
  id                VARCHAR(32) PRIMARY KEY,

  -- 可選共享關聯
  product_id        VARCHAR(32)
                    REFERENCES products(id)
                    ON DELETE SET NULL,

  name              VARCHAR(200) NOT NULL,
  category          VARCHAR(64),
  brand             VARCHAR(64),
  image             TEXT,
  description       TEXT,
  status            VARCHAR(32) NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active', 'inactive')),

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- 若一個販售商品只能對應一個租借主檔，保留此限制
  UNIQUE (product_id)
);
----


4. rental_sku_variants
id
rental_sku_id
sku
color
size
`label 一樣前端處理`
image
`description 變體租借說明，好多餘`

* 租借商品自己的變體，不再使用 product_variants。
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


5. rental_sku_variant_stocks
id
rental_sku_variant_id
`campground_id 庫存所在地，倉庫和營地會混在一起`
quantity

* 庫存改為指向 rental_sku_variants (有更好的做法，要拆表)
----
CREATE TABLE rental_sku_variant_stocks (
  id                    BIGSERIAL PRIMARY KEY,

  rental_sku_variant_id  VARCHAR(64) NOT NULL
                         REFERENCES rental_sku_variants(id)
                         ON DELETE CASCADE,

  campground_id         VARCHAR(32) NOT NULL,
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


6. rental_listings
id
rental_sku_id 租借商品主檔
rental_sku_variant_id
campground_id 提供租借的營區
sku
name
color
size
`spec_label 前端處理`
image_url
terrain_tag 地形標籤
`description 目前沒有`
price_per_day_weekday
price_per_day_holiday
discount
stock


* listing 應該指向租借變體，而不是販售變體。
----
CREATE TABLE rental_listings (
  id                    VARCHAR(32) PRIMARY KEY,

  rental_sku_id          VARCHAR(32) NOT NULL
                         REFERENCES rental_skus(id),

  rental_sku_variant_id  VARCHAR(64) NOT NULL
                         REFERENCES rental_sku_variants(id),

  campground_id          VARCHAR(32) NOT NULL
                         REFERENCES campgrounds(id),

  sku                   VARCHAR(64) NOT NULL,
  name                  VARCHAR(200) NOT NULL,
  color                 VARCHAR(64),
  size                  VARCHAR(64),
  spec_label            VARCHAR(128),
  image_url             TEXT,
  terrain_tag           VARCHAR(128),
  description           TEXT,

  price_per_day_weekday NUMERIC(12, 2) NOT NULL DEFAULT 0
                         CHECK (price_per_day_weekday >= 0),

  price_per_day_holiday NUMERIC(12, 2) NOT NULL DEFAULT 0
                         CHECK (price_per_day_holiday >= 0),

  discount              NUMERIC(12, 2) NOT NULL DEFAULT 0
                         CHECK (discount >= 0),

  -- 建議改成 VIEW 或由交易同步
  stock                 INTEGER NOT NULL DEFAULT 0
                         CHECK (stock >= 0),

  UNIQUE (campground_id, rental_sku_variant_id)
);
----

7. booking_selected_rentals
id
booking_id
rental_listing_id
rental_sku_id
rental_sku_variant_id
product_id 
`sku 快照`
`name 快照`
`spec_label 快照`
quantity 
unit_price 當時單價
subtotal


* 預約明細指向租借 listing 與租借變體。
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

  -- 共享商品時可保存；純租借商品則為 NULL
  product_id            VARCHAR(32)
                        REFERENCES products(id)
                        ON DELETE SET NULL,

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
