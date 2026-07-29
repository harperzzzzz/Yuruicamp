# 會員訂單列表與詳情

| 欄位 | 內容 |
|------|------|
| **狀態** | 已完成 |
| **端點** | `GET /api/me/orders`、`GET /api/me/orders/{orderId}` |
| **認證** | Firebase Bearer Token |
| **資料來源** | `orders`、`order_items` 快照 |

## 1. 用途

提供目前登入會員自己的訂單列表與單筆詳情。會員身分只採用後端解析的 `CustomerPrincipal`，API 不接受前端傳入 `customerId`，避免查詢其他會員訂單。

## 2. 主要流程

```text
Firebase Bearer Token
→ Security Filter 建立 CustomerPrincipal
→ Controller 取出 customerId
→ Service 呼叫本人限定 Repository 查詢
→ 組裝訂單與商品快照 DTO
→ 回傳統一 ApiResponse
```

列表依 `placedAt` 新到舊排列並附 `PageMeta`。目前契約 `v0.1` 回傳會員全部訂單，因此 `page=0`，有資料時 `totalPages=1`。

## 3. 回應規則

- 金額使用兩位小數字串。
- `paymentMethod` 使用契約值，例如 `ecpay-credit`。
- 商品 `lineTotal` 由 `unitPrice * quantity` 計算。
- 不回傳 `checkoutIdempotencyKey` 或 `checkoutRequestHash`。
- 他人訂單與不存在訂單都回 `404 NOT_FOUND`，避免透露訂單是否存在。
- 未登入請求回 `401 UNAUTHORIZED`。

## 4. 分層責任

- `MemberOrderController`：取得登入 principal、宣告 OpenAPI Bearer、回傳 Envelope。
- `MemberOrderService`：驗證會員身分、組裝金額與快照 DTO、統一 `404`。
- `OrderRepository`：依 `customerId` 限定列表與單筆查詢。
- `MemberOrderResponse`：定義會員可見的訂單與商品快照欄位。

## 5. 驗證結果

`MemberOrderPostgreSqlIntegrationTest` 使用真正 PostgreSQL 與專屬測試資料驗證：

- 本人列表只包含自己的訂單，且新到舊排列。
- 詳情包含訂單金額、付款狀態、Checkout 到期時間及商品快照。
- 他人與不存在訂單都回相同 `404`。
- 列表與詳情未登入都回 `401`。

執行結果：`4 tests、0 failure、0 error、0 skipped`。

人工驗證步驟見 [`member-order-api-validation.md`](../test/member-order-api-validation.md)。

