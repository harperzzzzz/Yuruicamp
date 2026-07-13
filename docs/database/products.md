# products

## problem : 
1. interest_tags、
2. images、
3. specifications、
4. tags 以 JSONB 存放多值或結構化屬性。
違反1NF
5. total_stock 是可由庫存明細彙總得出的衍生資料。
6. category、brand 以文字保存，未與分類/品牌主檔形成關聯完整性；且 brands 表存在但未被產品引用。

### 所有更動 :
* products 保留一張image 當主圖，再拆表(interest_tags, specifications, tags, images)
* product_images
* product_tags
* product_interest_tags
* product_specifications 

----
-- 商品圖片，多張圖 + 排序
CREATE TABLE product_images (
  product_id VARCHAR(32) NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  url TEXT NOT NULL,
  alt_text TEXT,
  PRIMARY KEY (product_id, sort_order)
);

-- 商品標籤，例如「帳篷」「Coleman」
CREATE TABLE product_tags (
  product_id VARCHAR(32) NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  tag VARCHAR(64) NOT NULL,
  PRIMARY KEY (product_id, tag)
);

-- 興趣標籤，例如 tent / safety / cooking
CREATE TABLE product_interest_tags (
  product_id VARCHAR(32) NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  interest_tag VARCHAR(64) NOT NULL,
  PRIMARY KEY (product_id, interest_tag)
);

-- 商品規格 key/value，例如 weight, capacity, material
CREATE TABLE product_specifications (
  product_id VARCHAR(32) NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  spec_key VARCHAR(64) NOT NULL,
  spec_value TEXT NOT NULL,
  PRIMARY KEY (product_id, spec_key)
);
----

### 如果要更詳細的規格，要進一步拆表 : (只有要做數字查詢才要在product_specifications 增加欄位)
* specification_definitions 

---
CREATE TABLE specification_definitions (
  key VARCHAR(64) PRIMARY KEY,
  label VARCHAR(100) NOT NULL,
  value_type VARCHAR(32) NOT NULL CHECK (value_type IN ('text', 'number', 'boolean')),
  unit VARCHAR(32)
);
---


* 有使用列表篩選、搜尋，一定要拆
* JSON 不要刪除做相容
* 可以加上索引提升效能
---
CREATE INDEX idx_product_tags_tag ON product_tags(tag);
CREATE INDEX idx_product_interest_tags_tag ON product_interest_tags(interest_tag);
CREATE INDEX idx_product_images_product_order ON product_images(product_id, sort_order);
CREATE INDEX idx_product_specs_key ON product_specifications(spec_key);
CREATE INDEX idx_product_specs_key_value ON product_specifications(spec_key, spec_value);
---


## prodcut_variants.md 有進行branch_stock 拆表，將total_stock 更動
products.total_stock 改成 view 或 trigger 維護的快取，不再手動寫入
* View (永遠最新，隨著variants 的關聯改變)
效率較低，要重新計算
---
CREATE VIEW product_stock_summary AS
SELECT
    pv.product_id,
    SUM(s.quantity) total_stock
FROM product_variants pv
JOIN inventory_stocks s
ON pv.id = s.variant_id
GROUP BY pv.product_id;
---

* Trigger（快取）
保留products.total_stock
效率較快、複雜、維護高、容易bug

## category、brand 改動 :
建立分類主檔，並讓產品引用分類與品牌 ID。
---
CREATE TABLE product_categories (
  id VARCHAR(32) PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);
---

products 改成 :
---
category_id VARCHAR(32) REFERENCES product_categories(id),
brand_id    VARCHAR(32) REFERENCES brands(id)
---
查詢時 :
---
SELECT
  p.id,
  p.name,
  c.name AS category_name,
  b.name AS brand_name
FROM products p
LEFT JOIN product_categories c ON c.id = p.category_id
LEFT JOIN brands b ON b.id = p.brand_id;
---