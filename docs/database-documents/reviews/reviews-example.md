# 資料表實際互動
reviews
review_photos
order_items
orders
customers


## 建立正式評價
* reviews
id                = REV031
order_item_id     = 418
rating            = 5
comment           = 暑假出貨很快，帳篷品質很棒！
created_at        = 2026-07-10 10:00:00+08
---
代表：
REV031 是針對訂單品項 418 的正式評價
評分為 5 星
同一個 order_item_id 不能再建立第二筆評價
---

## 建立評價圖片（組合示例）
* review_photos
review_id  sort_order  url
REV031     0           /assets/images/reviews/rev031-01.jpg
REV031     1           /assets/images/reviews/rev031-02.jpg
---
此示例假設 REV031 有兩張圖片
前端依 sort_order 由小到大顯示
---

## 由訂單關聯取得顯示資料
* order_items
id            = 418
order_id      = 208
product_id    = P001
variant_id    = v-P001-0
sku_snapshot  = v-P001-0
product_name_snapshot = Coleman 六人帳篷

* orders
id                    = 208
customer_id           = U027
buyer_name_snapshot   = 羅俊宏

* customers
id          = U027
avatar_url  = /assets/images/avatar-01.jpg
---
reviews 不重複保存會員、商品、規格與訂單資料
review_dto_view 透過 order_item_id 取得上述關聯與快照
---

## reviews 與 review_photos 組合後的前端資料（組合示例）
`review_dto_view` 對每筆正式評價輸出一個 payload；圖片由 review_photos 依 sort_order 聚合為 photos 陣列。
```json
{
  "id": "REV031",
  "customerId": "U027",
  "productId": "P001",
  "variantId": "v-P001-0",
  "sku": "v-P001-0",
  "orderId": 208,
  "orderItemId": 418,
  "buyerName": "羅俊宏",
  "buyerAvatar": "/assets/images/avatar-01.jpg",
  "productName": "Coleman 六人帳篷",
  "rating": 5,
  "comment": "暑假出貨很快，帳篷品質很棒！",
  "photos": [
    "/assets/images/reviews/rev031-01.jpg",
    "/assets/images/reviews/rev031-02.jpg"
  ],
  "createdAt": "2026-07-10 10:00:00",
  "verifiedPurchase": true
}
```
---
代表：
前端只需讀取 review_dto_view 的 payload
photos 已是依顯示順序排列的網址陣列
verifiedPurchase 固定為 true，因為每筆 reviews 都有可驗證的 order_item_id
---

## 沒有圖片的評價
目前來源中的 REV031 沒有對應的 review_photos；View 仍輸出：
```json
{
  "id": "REV031",
  "photos": [],
  "verifiedPurchase": true
}
```
`COALESCE` 會將沒有圖片的聚合結果轉為空陣列，前端不需要額外處理 NULL。
