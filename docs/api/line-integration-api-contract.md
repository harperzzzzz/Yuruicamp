# LINE n8n 訂單狀態客服 API 契約

| 欄位   | 內容                                                                      |
| ------ | ------------------------------------------------------------------------- |
| 狀態   | Implemented v0.1（MVP：只做綁定與來源訂單查詢）                          |
| 認證   | `POST /api/me/line-binding/code` 為 Firebase Bearer；internal API 為 `X-Internal-Api-Key` |
| 資料表 | 不修改 Yuruicamp 主資料庫；綁定碼與 `lineUserId` 對照存於 n8n／QA PostgreSQL |

> LINE 官方帳號連結：`https://lin.ee/NkgGfc4`（設定鍵 `yuruicamp.line-integration.official-account-url`）。
> 本輪只完成「從訂單詳情產生綁定碼」與「n8n 查詢來源訂單狀態」；不做 LINE Login／LIFF、多訂單查詢或解除綁定。

## POST `/api/me/line-binding/code`

登入會員從自己的訂單詳情頁產生一次性綁定碼。

Request：

```json
{
  "orderId": "1"
}
```

Response：

```json
{
  "bindCode": "839201",
  "bindText": "綁定 839201",
  "expiresAt": "2026-07-30T15:30:00Z",
  "lineUrl": "https://lin.ee/NkgGfc4"
}
```

規則：

- `orderId` 只接受目前登入會員自己的訂單；不屬於本人或不存在都回 `404 NOT_FOUND`，`error.message` 固定為「查無此訂單」。
- `bindCode` 為 6 位數亂數，`expiresAt` 為建立時間 +10 分鐘。
- 前端顯示的綁定提示文字**必須**使用回應中的 `bindText`（或以 `bindCode` 組成 `'綁定 ' + bindCode`），不可在畫面上寫死綁定碼。
- 建立成功後，後端會呼叫 `yuruicamp.line-integration.binding-code-webhook-url` 指定的 n8n Webhook，帶入 `bindCode`／`customerId`／`orderId`／`expiresAt`，並附上 `X-Internal-Api-Key`。
- 若 Webhook 網址尚未設定，回 `409 CONFLICT`，`error.message` 為「LINE 綁定服務尚未設定」；呼叫失敗回 `500 INTERNAL_ERROR`。
- 未登入回 `401 UNAUTHORIZED`。

## GET `/api/internal/line/orders/{orderId}?customerId=xxx`

供 n8n 使用已綁定的 `customerId` 與來源 `orderId` 查詢訂單摘要，讓 LINE 客服回覆訂單狀態。

Header：

```text
X-Internal-Api-Key: <yuruicamp.line-integration.internal-api-key>
```

Response：

```json
{
  "id": "1",
  "displayNo": "ORD-0001",
  "status": "completed",
  "paymentStatus": "unpaid",
  "paymentMethod": "cod",
  "total": "680.00",
  "placedAt": "2026-07-26T11:02:51Z",
  "items": [
    { "productName": "戶外清涼袋", "quantity": 1 }
  ]
}
```

規則：

- 缺少或錯誤的 `X-Internal-Api-Key` 一律回 `403 FORBIDDEN`。
- `orderId` 或 `customerId` 為空白回 `400 VALIDATION_ERROR`。
- `orderId` 不屬於該 `customerId`（或不存在）回 `404 NOT_FOUND`，`error.message` 固定為「查無此訂單」；n8n 收到此錯誤時應回覆 LINE 使用者「查無此訂單」。
- 回應**不包含** `buyerEmail`、`recipientName`、`shippingAddress`、`shippingPhone` 等個資欄位。
- 商品只回 `productName` 與 `quantity`；金額為兩位小數字串；時間為 ISO-8601。
- 本端點在 `SecurityConfig` 中設定 `/api/internal/line/**` 為 `permitAll`（略過 Firebase Bearer），實際驗證完全由 Controller 內的 `X-Internal-Api-Key` 檢查負責。

## n8n 串接摘要

詳細 Workflow 規劃與 QA PostgreSQL 表結構見 [`docs/backend-specs/integration/line-n8n-order-status-mvp.md`](../backend-specs/integration/line-n8n-order-status-mvp.md)。此部分不是本專案程式碼，由 n8n 環境另行建置。
