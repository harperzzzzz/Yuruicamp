# articles：文章主檔
# article_content_blocks：文章內容區塊
# article_related_products：文章推薦商品關聯表
# products：商品主檔

## OneToMany 
* article (1) : article_content_blocks (N)
* article_content_blocks (N) : products (1)
## ManyToMany
* products (N) : article_related_products (N)


1. articles：文章主檔
id
title
category 文章分類搜尋用
author 作者名稱
author_avatar 頭像
published_date 發布日期
read_time 閱讀分鐘數
image
excerpt 文章摘要(預覽)
tags  文章底部多個
is_featured 是否為精選文章(T/F)

*使用網頁: pages/blog.html*
*使用網頁: pages/blog-detail.html*


2. article_content_blocks：文章內容區塊
id
articles_id 
sort_order  區塊顯示順序(10, 20) 因為太多不同類型的渲染，需要有順序的渲染去讓js 決定填入區塊
    `補上UNIQUE (article_id, sort_order)，同一篇文章中，不能有兩個區塊使用相同順序。`
type 決定渲染類型text、heading、product，對應html 標籤
    `是 text, heading 時value 不能null, product 必為null`
    `是 prdocut 時value 可以是null, product 不能是null`
value 段落內容 (看要不要改名，包含header, text 內容)，有prodcut時 null
product_id 類型不是product 為null

*使用網頁: pages/blog-detail.html*
## Note : 文章段落分太多組件了，需要用額外的表安排渲染順序。

### article_content_blocks 建議補上兩個約束，避免不合理資料：
-----
ALTER TABLE article_content_blocks
ADD CONSTRAINT uq_article_block_order
UNIQUE (article_id, sort_order);

ALTER TABLE article_content_blocks
ADD CONSTRAINT ck_article_content_block_payload
CHECK (
  (type IN ('text', 'heading') AND value IS NOT NULL AND product_id IS NULL)
  OR
  (type = 'product' AND product_id IS NOT NULL)
);
-----


3. article_related_products：文章推薦商品關聯表
article_id
product_id


4. products：商品主檔
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
specifications 防水係數、材質...
tags 
total_stock 商品總庫存快取
created_at
updated_at

## Note : 當article_content_blocks 的type = 'product' 時，以 product_id 讀取商品，渲染內嵌商品卡。

