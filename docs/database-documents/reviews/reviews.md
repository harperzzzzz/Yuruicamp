# reviews
* reviews
    已購買商品的正式評價；每個訂單品項至多一筆。
* review_photos
    正式評價的圖片，依排序顯示。


## 關聯與資料流
customers
└─ 1:N orders
      └─ 1:N order_items
            └─ 0..1:1 reviews
                     └─ 1:N review_photos

### 關聯
* reviews：只透過 order_item_id 關聯訂單品項；訂單、會員、商品與規格資料皆由 order_items 及其上游關聯取得。
* review_photos：以 review_id 關聯正式評價；父評價更新時連動更新，刪除時連帶刪除圖片。

### 資料流程
正式評價建立後：
1. 先確認評價對應一筆存在的 order_items。
2. 在 reviews 建立評分與評論內容。
3. 每個 order_item_id 僅能建立一筆 reviews，避免同一購買品項重複評價。
4. 有圖片時，依顯示順序寫入 review_photos。
5. 對外讀取由 review_dto_view 組合訂單、會員、商品快照及圖片，並標示 verifiedPurchase = true。


## 欄位說明
### reviews
* id                評價識別碼。
* order_item_id     已購買訂單品項識別碼。UNIQUE，同一訂單品項最多一筆正式評價。
* rating            評分，只允許 1 至 5。
* comment           評論文字，NULL。

* created_at        建立時間，預設 now()。
                    *idx_reviews_created_at*

### review_photos
* review_id         正式評價識別碼。
                    父評價更新時連動更新；刪除時連帶刪除圖片。

* sort_order        圖片顯示順序，必須大於等於 0。
* url               圖片網址，不可為空白字串。
*(review_id, sort_order) 是複合主鍵*



## 運作模式
* 會員購買後的正式評價 > reviews、review_photos
* 前台或後台需要完整顯示資料 > review_dto_view



## 程式碼追蹤
* 評價 DTO 輸出
    `review_dto_view`
                ↓
    reviews
        → order_items
        → orders
        → customers
        → review_photos
                ↓
    組合商品、規格、訂單、會員與圖片資訊
    verifiedPurchase = true

    * 資料庫 View 僅輸出正式評價。
    * 正式評價商品與會員資訊由訂單關聯重建；圖片依 review_photos.sort_order 聚合。


## 可能的問題
* 高風險：移除 legacy_reviews 後，缺少 orderId 的 37 筆舊評價不再出現在 review_dto_view；若仍要顯示，需先補齊可驗證的 order_item_id，或另行規劃讀取原始 JSON 的相容方式。

* 高風險：前端目前仍讀取 data/admin/reviews.json 與 localStorage Mock，不直接讀取 review_dto_view 或這兩張 PostgreSQL 資料表。

* 中風險：review_photos 僅限制 URL 不可空白，未限制網址協定、網域或檔案可用性。

* 低風險：reviews 的 comment 可為 NULL，使用端應能顯示純星等評價。
