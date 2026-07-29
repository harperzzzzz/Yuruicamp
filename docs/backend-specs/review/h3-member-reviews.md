# H-3 會員已購商品評論

## 完成範圍

- Firebase Principal 專用 `GET／POST /api/me/reviews`。
- 建立前鎖定 `order_items`，同一交易驗證所有權、訂單狀態與重複評論。
- 只有 `completed` 訂單明細可評價。
- 同一個 `orderItemId` 最多一則評論。
- 前端 Backend 模式透過 `ApiClient._restRequest()` 呼叫正式 API。
- Mock 模式保留原本 JSON／`mockReviews` 行為。
- 空白評論內容正規化為 `null`，非空白內容限制 `1000` 字。
- 業務錯誤使用 `REVIEW_ORDER_FORBIDDEN`、`REVIEW_ORDER_NOT_COMPLETED`、
  `REVIEW_ALREADY_EXISTS`，供前端顯示可採取行動的提示。

## 尚未包含

- 軟隱藏、檢舉或管理員回覆。

## 交易與資料來源

1. Controller 只收 `orderItemId`、`rating`、`comment`。
2. Service 鎖定 `order_items`，再使用 Principal 的 `customerId` 驗證所有權。
3. 訂單、商品、規格及會員資料皆從資料庫關聯取得。
4. 先檢查 `reviews.order_item_id`，再新增評論。
5. `uq_reviews_order_item_id` 防止併發重複寫入。

## Spring Bean 建立

`MemberReviewService` 同時保留正式依賴建構子與可注入 `Clock` 的測試建構子。
正式建構子使用 `@Autowired` 明確指定，避免 Spring 在多建構子情況下尋找不存在的無參數建構子。
`MemberReviewServiceSpringWiringTest` 使用最小 Spring Context 驗證 Bean 能正常建立，不依賴 PostgreSQL。
