# order_item

## problems :
1. order_items 同時保存商品 FK 與 sku、name、spec_label、color、size、brand、image、price 快照資料，存在非正規化冗餘

## 改動 :
* 決定欄位語意
---
-- 關聯用：追蹤商品、報表、庫存、售後
product_id
variant_id

-- 快照用：歷史訂單顯示、對帳，不跟商品主檔同步
sku_snapshot
product_name_snapshot
spec_label_snapshot
brand_snapshot
image_snapshot
unit_price_snapshot
quantity
---

* Schema 改名
sku > sku_snapshot
name > product_name_snapshot
spec_label > spec_label_snapshot
brand > brand_snapshot
image > image_snapshot
price > unit_price_snapshot

---
CREATE TABLE order_items (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,

  product_id VARCHAR(32) NOT NULL REFERENCES products(id),
  variant_id VARCHAR(64) NOT NULL REFERENCES product_variants(id),

  sku_snapshot VARCHAR(64) NOT NULL,
  product_name_snapshot VARCHAR(200) NOT NULL,
  spec_label_snapshot VARCHAR(128),
  brand_snapshot VARCHAR(64),
  image_snapshot TEXT,
  unit_price_snapshot NUMERIC(12, 2) NOT NULL,

  quantity INTEGER NOT NULL CHECK (quantity > 0)
);
---

* 寫入訂單時改 payload mapping
---
{
  productId,
  variantId,
  skuSnapshot: sku,
  productNameSnapshot: name,
  specLabelSnapshot: specLabel,
  brandSnapshot: brand,
  imageSnapshot: image,
  unitPriceSnapshot: price,
  quantity
}
---
下單當下寫入一次，之後商品改名、改價、換圖，都不更新舊訂單。

* 顯示端改讀 snapshot 欄位
---
item.productNameSnapshot
item.specLabelSnapshot
item.unitPriceSnapshot
item.imageSnapshot

item.unitPriceSnapshot * item.quantity
---

