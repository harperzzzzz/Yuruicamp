# products

# orders

# customers

# reviews

# OneToMany

- customers 1 : reviews N
- products 1 : reviews N
- product_variants 1 : N reviews 但 reviews.variant_id 可為 null
- orders 1 ── N reviews 但 reviews.order_id 可為 null

## problems :

1. docs/schema.sql 的reviews.photos 以 JSONB 存放多張照片。
2. reviews 同時保存 FK 與 sku、buyer_name、buyer_avatar、product_name。
3. variant_id、order_id、sku 不保證資料正確性。
4. 現行 `docs/schema.sql` 尚有 `replied` 與 `reply_*`、`replied_*` 欄位，但專案已定案不提供賣家／官方回覆功能；這些欄位不納入目標模型。

## reviews.photos 更動 :

- 固定 reviews.photos 存「多張照片 URL 陣列」：
  現在前端會讀取photos 為url(String) ，目前為object 會不相容

---

[
"/assets/images/review-photo-01.jpg",
"/assets/images/review-photo-02.jpg"
]

---

- chema 變更：

---

建議欄位預設[] ，null 的定義不明確(沒接收到還是bug?)
ALTER TABLE reviews
ALTER COLUMN photos SET DEFAULT '[]'::jsonb;

ALTER TABLE reviews
ALTER COLUMN photos SET NOT NULL;

ALTER TABLE reviews
ADD CONSTRAINT chk_reviews_photos_array
加上 JSON 型別約束，避免寫入物件或字串：
CHECK (jsonb_typeof(photos) = 'array');

---

1. review 評論表
   id
   customer_id
   product_id
   variant_id：真正關聯 product_variants 的 FK
   order_id
   sku：評論當下的 SKU 快照，只供顯示與歷史追溯
   buyer_name 快照 (要簡化還是要留)
   buyer_avatar 快照 (要簡化還是要留)
   product_name 快照 (要簡化還是要留)
   rating
   comment 評論
   photos 圖片
   created_at

## 建議補索引 : (搜尋更快)

---

CREATE INDEX idx_reviews_product ON reviews(product_id);
CREATE INDEX idx_reviews_customer ON reviews(customer_id);
CREATE INDEX idx_reviews_order ON reviews(order_id);
CREATE INDEX idx_reviews_variant ON reviews(variant_id);
CREATE INDEX idx_reviews_created_at ON reviews(created_at);

---

## 官方回覆定案

- 不提供賣家或官方回覆評論的功能。
- 不建立 `review_replies`。
- 目標 `reviews` 移除 `replied`、`reply_text`、`reply_at`、`replied_by`、`replied_by_name`、`reply_updated_at`。
- API／DTO 不接受也不輸出任何官方回覆欄位。
- 目前 `data/admin/reviews.json` 沒有官方回覆資料，因此不需要回填或保存回覆歷史。

## variant_id、order_id、sku 改動 :

- variant_id 必須屬於同一個 product_id
  在 product_variants 補複合唯一鍵：

---

ALTER TABLE product_variants
ADD CONSTRAINT uq_product_variants_product_id_id
UNIQUE (product_id, id);

---

- product_id, variant_id 一起 FK：(防止錯誤資料)

---

ALTER TABLE reviews
ADD CONSTRAINT fk_reviews_product_variant
FOREIGN KEY (product_id, variant_id)
REFERENCES product_variants(product_id, id);

---

- order_id 必須真的包含該商品 / 規格，在 order_items 補唯一鍵：

---

ALTER TABLE order_items
ADD CONSTRAINT uq_order_items_order_product_variant
UNIQUE (order_id, product_id, variant_id);

---

- order_id, product_id, variant_id FK 到 order_items

---

ALTER TABLE reviews
ADD CONSTRAINT fk_reviews_order_item
FOREIGN KEY (order_id, product_id, variant_id)
REFERENCES order_items(order_id, product_id, variant_id);

---

- order_id 改成not null

---

ALTER TABLE reviews
ALTER COLUMN order_id SET NOT NULL;

---

- 同一訂單同一商品規格只能評論一次

---

CREATE UNIQUE INDEX uq_reviews_order_product_variant
ON reviews(order_id, product_id, variant_id)
WHERE order_id IS NOT NULL;

---

- sku 明確定義成快照，不是關聯鍵
  新增評論時，後端應從 product_variants.sku 帶入：

---

SELECT sku
FROM product_variants
WHERE id = :variant_id
AND product_id = :product_id;

---

不要相信前端送來的 sku，避免前端竄改。
