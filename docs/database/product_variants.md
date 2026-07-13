# product_variants

## problem :
branch_stock JSONB 違反1NF

## 主要影響 :
* 無法保證分店一定存在
* 無法限制 數量 >= 0
* 無法驗證每個 SKU × 據點最多只有一筆庫存
* `branches 刪除分店時，JSON 會有殘留，雖然沒有刪除分店功能`
* 無法保證調撥的一致性




### 新增一張庫位主檔、一張庫存餘額表
* 庫位主檔

---
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
---


* 庫存餘額表

---
CREATE TABLE inventory_stocks (
  location_id       VARCHAR(32) NOT NULL
                    REFERENCES inventory_locations(id),
  variant_id        VARCHAR(64) NOT NULL
                    REFERENCES product_variants(id)
                    ON DELETE CASCADE,
  on_hand_quantity  INTEGER NOT NULL DEFAULT 0,
  reserved_quantity INTEGER NOT NULL DEFAULT 0,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  PRIMARY KEY (location_id, variant_id),

  CHECK (on_hand_quantity >= 0),
  CHECK (reserved_quantity >= 0),
  CHECK (reserved_quantity <= on_hand_quantity)
);
---


* 不要把main 放進branches
- data/marketing/branches.json
建議：
main 建成 inventory_locations.type = 'warehouse'
branch-001、branch-002、branch-003 對應 branches.id
未來營地庫存可用 type = 'campground'
範例：
---
INSERT INTO inventory_locations (id, code, name, type)
VALUES ('loc-main', 'main', '主倉', 'warehouse');

INSERT INTO inventory_locations (id, code, name, type, branch_id)
SELECT
  'loc-' || id,
  id,
  name,
  'branch',
  id
FROM branches;
---

* 必要索引 :
---
CREATE INDEX idx_inventory_stocks_variant
  ON inventory_stocks(variant_id);

CREATE INDEX idx_inventory_stocks_location
  ON inventory_stocks(location_id);
---

* JSON 保留保持相容
* 不要讓 movement_items.from_store、to_store 存顯示字串。應改成 FK：
---
source_location_id      VARCHAR(32) REFERENCES inventory_locations(id),
destination_location_id VARCHAR(32) REFERENCES inventory_locations(id)
---
* inventory_movement_items 綁 SKU
---
variant_id VARCHAR(64) NOT NULL REFERENCES product_variants(id),
quantity   INTEGER NOT NULL CHECK (quantity > 0)
---