# min_stocks

## problems :
1. target_type + target_id 是多型關聯，target_id 無法用單一外鍵保證必定指向 products 或 rental_skus。
2. location_key 混用 main、branch-*、C*，無法用外鍵保證地點有效。

# 改動 :
刪除min_stocks 資料表。
不要再讓 min_stocks 指向 products 或 rental_skus 主檔，而是直接指向真正有庫存的 SKU variant + location。

* 販售最低庫存：
---
CREATE TABLE product_variant_min_stocks (
  product_variant_id VARCHAR(64) NOT NULL
    REFERENCES product_variants(id)
    ON DELETE CASCADE,

  location_id VARCHAR(32) NOT NULL
    REFERENCES inventory_locations(id),

  min_quantity INTEGER NOT NULL DEFAULT 0
    CHECK (min_quantity >= 0),

  PRIMARY KEY (product_variant_id, location_id)
);
---

* 租借最低庫存：
---
CREATE TABLE rental_sku_variant_min_stocks (
  rental_sku_variant_id VARCHAR(64) NOT NULL
    REFERENCES rental_sku_variants(id)
    ON DELETE CASCADE,

  location_id VARCHAR(32) NOT NULL
    REFERENCES inventory_locations(id),

  min_quantity INTEGER NOT NULL DEFAULT 0
    CHECK (min_quantity >= 0),

  PRIMARY KEY (rental_sku_variant_id, location_id)
);
---