# 會員商品評論 API 契約

評論 `comment` 最長為 `1000` 個字元，後端以純文字內容保存。HTML 安全性由每個輸出端依其輸出情境處理；商品頁不得把評論、買家姓名、日期或圖片 URL 直接插入 `innerHTML`。

## 評論圖片

`POST /api/me/reviews/photos?orderItemId={id}` 使用 `multipart/form-data`，欄位名稱為 `files`。

- 僅限目前會員已完成且尚未評論的訂單明細。
- 每次 `1` 至 `5` 張。
- 支援 JPEG、PNG、WebP。
- 每張最多 `5 MB`。
- 後端同時檢查宣告 MIME 與檔案特徵碼，不信任副檔名。
- 回傳 `{ "urls": [...] }`，建立評論時放入 `photoUrls`。
- `photoUrls` 最多 `5` 筆，且必須屬於目前會員與該 `orderItemId` 的上傳路徑。

## 管理自己的評論

- `GET /api/me/reviews`：列出目前會員完整評論。
- `PATCH /api/me/reviews/{reviewId}`：修改星等、純文字內容與照片 URL 清單。
- `DELETE /api/me/reviews/{reviewId}`：刪除評論，成功回傳 `204 No Content`。

`PATCH` 與 `DELETE` 都以 Firebase Principal 限制評論所有權。評論不存在或屬於其他會員時統一回傳 `404 NOT_FOUND`，不洩漏評論是否存在。建立評論或上傳照片時，若訂單明細存在但不屬於目前會員，回傳 `403 REVIEW_ORDER_FORBIDDEN`。修改照片時會重新建立 `sort_order`；移除及刪除的本機圖片會同步清理。

## 範圍

本契約只處理目前 Firebase Principal 自己的已購商品評論。會員身分由 Bearer Token 決定，Request 不接受 `customerId`、`productId`、`orderId`、買家姓名或建立時間。

## 端點

| Method | Path | Auth | 說明 |
| --- | --- | --- | --- |
| `GET` | `/api/me/reviews` | Firebase Bearer | 讀取目前會員全部評論，依建立時間新到舊 |
| `POST` | `/api/me/reviews` | Firebase Bearer | 為本人已完成訂單的單一 `orderItemId` 建立評論 |

## 建立 Request

```json
{
  "orderItemId": 602081,
  "rating": 5,
  "comment": "商品很實用"
}
```

規則：

- `orderItemId` 必填且必須大於 `0`。
- `rating` 必須為 `1`～`5`。
- `comment` 可為 `null`；只包含空白時保存為 `null`，非空白內容去除首尾空白後最多 `1000` 字。
- `orderItemId` 必須屬於目前登入會員。
- 對應訂單狀態必須為 `completed`。
- 同一個 `orderItemId` 最多一則評論；資料庫唯一鍵是最後防線。
- `reviewId`、會員、商品、規格、訂單及建立時間全部由後端決定。

## Response

```json
{
  "success": true,
  "data": {
    "id": "32字元UUID",
    "orderItemId": 602081,
    "orderId": "208",
    "customerId": "U031",
    "productId": "P001",
    "variantId": "V001",
    "sku": "SKU-001",
    "productName": "商品名稱快照",
    "buyerName": "會員名稱快照",
    "rating": 5,
    "comment": "商品很實用",
    "photos": [],
    "verifiedPurchase": true,
    "createdAt": "2026-07-23T08:00:00Z"
  }
}
```

## 錯誤

| 情境 | HTTP／code |
| --- | --- |
| 未登入 | `401 UNAUTHORIZED` |
| Request 格式錯誤 | `400 VALIDATION_ERROR` |
| 明細不存在 | `404 NOT_FOUND` |
| 明細不屬於本人 | `403 REVIEW_ORDER_FORBIDDEN` |
| 訂單尚未完成 | `409 REVIEW_ORDER_NOT_COMPLETED` |
| 同一明細已評價 | `409 REVIEW_ALREADY_EXISTS` |

前端應以穩定 `error.code` 顯示對應提示，不應比對英文 `message`。
