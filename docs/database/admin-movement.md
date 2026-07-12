# movements
# movement_items
# products

## OneToMany 
* movemet_items (N) > movements (1)
* movemet_items (N) > products(1)
一張異動單可以包含多筆商品異動
同一商品也可出現在多張異動單中


1. movements：庫存異動單頭
id
employee_id 異動單的人員 ID
created_at


2. movement_items：庫存異動明細
id
movement_id 異動單 ID
product_id
    `沒有設為IS NOT NULL`
prodcut_name 商品快照
quantity
    `CHECK (quantity > 0); 加上限制異動不會為零`
from_store 來源庫位(扣除)
to_store 目的庫位(增加)
type 異動類型，由後臺js 判斷產生
## 建議新增: variant_id、sku
- variant_id 關聯規格表 (不能用products 來找variants 會分不清楚要找哪個規格)
- sku 規格快照

## Note : type 應有明確的欄位規則
| `type` | `from_store` | `to_store` | 庫存效果 |
|---|---|---|---|
| 進貨 | `NULL` 或供應商 | 倉庫／門市 | 目的地增加 |
| 移轉 | 來源庫位 | 目的庫位 | 來源減少、目的增加 |
| 損耗 | 倉庫／門市 | `NULL` | 來源減少 |
| 盤點增加 | `NULL` | 倉庫／門市 | 目的地增加 |
| 盤點減少 | 倉庫／門市 | `NULL` | 來源減少 |


3. products：商品主檔
id
rental_id
rental_enabled
name
category
brand
interest_tags
price
status
image
images
description
specifications 規格 JSON
tags 
total_stock 商品總庫存快取
created_at
updated_at



## Note : (不一定要改因為js 把人工成分排除了，但是有更好更嚴謹的作法)
- movement_items.type 改成ENUM 因為是固定行為，js 變動時不用更改資料庫。




# 比較有問題需要新增表(from_store, to_store) : 
調撥的新增太多人工因素會導致資料庫庫存無法判斷造成數量不對齊

branches
   │ 0..1
   └──── inventory_locations
                 │ 1
                 ├──── inventory_stocks
                 │           │ N
                 │           └──── product_variants
                 │
                 ├──── inventory_movements（來源庫位）前身from_store
                 └──── inventory_movements（目的庫位）前身to_store

inventory_movements
   │ 1
   └──── inventory_movement_items
                 │ N
                 └──── product_variants

1. inventory_locations 庫位主檔 (新增)
id
code 人員辨識用代碼
name 庫位顯示名稱
`type 庫位類型 (warehouse 倉庫、branch 門市、campground 營地、repair 維修區、damaged 損壞／報廢區) 可能只留下branch 和campground?? ，但是更正式的作法是五種`
branch_id
campground_id
is_active 是否仍可被選為異動來源或目的地 (true 為來源，false 為目的) 0不可能為異動來源，可以避免UI操作失誤。
crated_at
updated_at
-----
CREATE TYPE inventory_location_type AS ENUM (
  'warehouse',
  'branch',
  'campground',
  'repair',
  'damaged'
);

CREATE TABLE inventory_locations (
  id              VARCHAR(32) PRIMARY KEY,
  code            VARCHAR(64) NOT NULL UNIQUE,
  name            VARCHAR(200) NOT NULL,
  type            inventory_location_type NOT NULL,
  branch_id       VARCHAR(32) UNIQUE REFERENCES branches(id),
  campground_id   VARCHAR(32) UNIQUE REFERENCES campgrounds(id),
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CHECK (
    (type = 'branch' AND branch_id IS NOT NULL AND campground_id IS NULL)
    OR
    (type = 'campground' AND campground_id IS NOT NULL AND branch_id IS NULL)
    OR
    (type NOT IN ('branch', 'campground')
      AND branch_id IS NULL
      AND campground_id IS NULL)
  )
);
-----

2. inventory_stocks：目前庫存餘額 (新增)
location_id 庫存在哪一個庫位
variant_id 商品規格
on_hand_quantity 實際持有數量
`reserved_quantity 已被訂單或預約保留、暫時不可再賣的數量 (考慮因為沒有預購功能)`
updated_at
----
CREATE TABLE inventory_stocks (
  location_id       VARCHAR(32) NOT NULL
                    REFERENCES inventory_locations(id),
  variant_id        VARCHAR(64) NOT NULL
                    REFERENCES product_variants(id),
  on_hand_quantity  INTEGER NOT NULL DEFAULT 0,
  reserved_quantity INTEGER NOT NULL DEFAULT 0,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (location_id, variant_id),

  CHECK (on_hand_quantity >= 0),
  CHECK (reserved_quantity >= 0),
  CHECK (reserved_quantity <= on_hand_quantity)
);
----


3. inventory_movements：庫存異動單頭 (改動自 movements)
id
movent_no 單號
`type 異動類 receipt 進貨、transfer 調貨、adjustment_in 盤點後補增、adjustment_out 盤點後扣減、write_off 損耗、破損、報廢、return`
status 草稿、已過帳、已取消
source_location_id  扣除庫存的來源庫位
destination_location_id 增加庫存的目的庫位
employee_id
reason
note 備註
occurred_at 實際發生異動的時間
posted_at 真正寫入庫存餘額的時間
created_at 建立草稿的時間
----
CREATE TYPE inventory_movement_type AS ENUM (
  'receipt',
  'transfer',
  'adjustment_in',
  'adjustment_out',
  'write_off',
  'return'
);

CREATE TYPE inventory_movement_status AS ENUM (
  'draft',
  'posted',
  'cancelled'
);

CREATE TABLE inventory_movements (
  id                      BIGSERIAL PRIMARY KEY,
  movement_no             VARCHAR(64) NOT NULL UNIQUE,
  type                    inventory_movement_type NOT NULL,
  status                  inventory_movement_status NOT NULL DEFAULT 'draft',
  source_location_id      VARCHAR(32)
                          REFERENCES inventory_locations(id),
  destination_location_id VARCHAR(32)
                          REFERENCES inventory_locations(id),
  employee_id             VARCHAR(32),
  reason                  TEXT,
  note                    TEXT,
  occurred_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  posted_at               TIMESTAMPTZ,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CHECK (
    source_location_id IS NULL
    OR destination_location_id IS NULL
    OR source_location_id <> destination_location_id
  )
);
----

4. inventory_movement_items：異動品項明細 (改動自movement_items)
id
movement_id
variant_id 異動的 SKU
quantity 異動數量
note 補充原因
----
CREATE TABLE inventory_movement_items (
  id            BIGSERIAL PRIMARY KEY,
  movement_id   BIGINT NOT NULL
                REFERENCES inventory_movements(id) ON DELETE CASCADE,
  variant_id    VARCHAR(64) NOT NULL
                REFERENCES product_variants(id),
  quantity      INTEGER NOT NULL,
  note          TEXT,

  UNIQUE (movement_id, variant_id),
  CHECK (quantity > 0)
);
----
