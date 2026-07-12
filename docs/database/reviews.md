# products
# orders
# customers
# reviews

# OneToMany
- customers 1 : reviews N
- products 1 : reviews N
- product_variants 1 : N reviews 但 reviews.variant_id 可為 null
- orders 1 ── N reviews 但 reviews.order_id 可為 null



1. review 評論表
id
customer_id
product_id
variant_id
order_id
sku 規格快照
buyer_name 快照 (要簡化還是要留)
buyer_avatar 快照 (要簡化還是要留)
product_name 快照 (要簡化還是要留)
rating
comment 評論
photos 圖片
replied 後台是否已回覆
reply_text 店家回覆內容
reply_at
replied_by 回覆者 ID
replied_by_name 快照
reply_updated_at
created_at

## Note : 
1. 沒有限制同一訂單同一商品只能評論一次
    ----
    CREATE UNIQUE INDEX uq_reviews_order_product_variant
    ON reviews(order_id, product_id, variant_id)
    WHERE order_id IS NOT NULL;
    ----
2. 沒有保證 variant_id 屬於同一個 product_id (沒有驗證屬於同一個產品) 防資料竄改攻擊
3. 沒有保證 order_id 的訂單真的包含該商品 (沒有驗證屬於同一個產品) 防資料竄改攻擊

## 建議補索引 : (搜尋更快)
----
CREATE INDEX idx_reviews_product ON reviews(product_id);
CREATE INDEX idx_reviews_customer ON reviews(customer_id);
CREATE INDEX idx_reviews_order ON reviews(order_id);
CREATE INDEX idx_reviews_variant ON reviews(variant_id);
CREATE INDEX idx_reviews_created_at ON reviews(created_at);
----