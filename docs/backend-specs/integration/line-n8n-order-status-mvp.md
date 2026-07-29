# LINE n8n 訂單狀態客服 MVP

| 欄位 | 內容 |
|------|------|
| **狀態** | 已完成（後端 API；n8n Workflow 由 n8n 環境另行建置） |
| **端點** | `POST /api/me/line-binding/code`、`GET /api/internal/line/orders/{orderId}?customerId=` |
| **認證** | 前者 Firebase Bearer（會員本人）；後者 `X-Internal-Api-Key` |
| **資料來源** | `orders`、`order_items` 快照（不修改主資料庫 schema） |

## 1. 用途

讓會員可以從訂單詳情頁產生一次性綁定碼，到 LINE 官方帳號輸入後由 n8n 綁定 `lineUserId ↔ customerId` 並記住來源 `orderId`；之後使用者在 LINE 問「訂單狀態」時，n8n 透過 internal API 查該筆訂單摘要回覆。

## 2. 主要流程

```text
會員登入 Yuruicamp
→ 進入會員中心訂單詳情
→ 點擊「使用 LINE 詢問訂單」
→ POST /api/me/line-binding/code（確認訂單屬於本人）
→ 後端產生 6 位數 bindCode，呼叫 n8n Webhook 寫入 bindCode/customerId/orderId/expiresAt
→ 前端顯示後端回傳的 bindText（例如「綁定 839201」）
→ 使用者到 LINE 輸入該綁定文字
→ n8n 綁定 lineUserId ↔ customerId，記住 lastOrderId
→ 使用者在 LINE 問「訂單狀態」
→ n8n 呼叫 GET /api/internal/line/orders/{orderId}?customerId=
→ LINE 回覆該訂單目前狀態
```

## 3. 回應規則

- 綁定碼建立：訂單不屬於本人或不存在一律回 `404 NOT_FOUND`，訊息固定「查無此訂單」，避免透露訂單是否存在。
- 綁定碼建立：Webhook 網址未設定回 `409 CONFLICT`；呼叫 n8n 失敗回 `500 INTERNAL_ERROR`。
- Internal 查單：`X-Internal-Api-Key` 缺漏或錯誤一律 `403 FORBIDDEN`；`orderId`／`customerId` 空白回 `400 VALIDATION_ERROR`；查無歸屬回 `404 NOT_FOUND`（訊息同上）。
- Internal 查單回應**不含**收件人、電話、Email 等個資欄位，只回狀態、付款、金額與商品名稱／數量摘要。
- 前端顯示的綁定文字一律使用後端回傳的 `bindText`，不得在畫面上寫死綁定碼。

## 4. 分層責任

- `LineBindingController`（`integration.line.api`）：登入 principal、呼叫 Service、回傳 Envelope。
- `LineBindingCodeService`（`integration.line.application`）：確認訂單歸屬本人、產生綁定碼、組回應。
- `LineBindingCodeWebhookClient`（`integration.line.infrastructure`）：以 `RestClient` 呼叫 n8n Webhook，帶 `X-Internal-Api-Key`。
- `InternalLineOrderController`／`InternalLineOrderService`：驗證 internal API key、查詢並組裝訂單摘要。
- `OrderRepository.findForCustomer(orderId, customerId)`：兩個端點共用，確保訂單一定歸屬指定會員。
- `YuruicampProperties.LineIntegration`：`internal-api-key`、`binding-code-webhook-url`、`official-account-url` 三個設定鍵。

## 5. n8n 端資料表（不在本專案資料庫）

綁定資料存放於 n8n 使用的 QA PostgreSQL 或獨立業務資料庫，不進入 Yuruicamp 主 schema：

```sql
create table if not exists line_binding_codes (
  bind_code text primary key,
  customer_id text not null,
  order_id text not null,
  expires_at timestamptz not null,
  used_at timestamptz null,
  created_at timestamptz not null default now()
);

create table if not exists line_user_bindings (
  line_user_id text primary key,
  customer_id text not null,
  last_order_id text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

n8n 綁定分支：收到 LINE 使用者輸入的綁定文字後，解析 `bindCode`，查 `line_binding_codes` 確認存在、未過期、未使用，取得 `customerId`／`orderId`，upsert `line_user_bindings`，並標記 `used_at`。

n8n 查詢分支：使用者輸入「訂單狀態」等文字時，查 `line_user_bindings` 取得 `customerId`／`lastOrderId`，呼叫本文件 §「主要流程」中的 internal API，依回應組成 LINE 回覆文字；查無來源訂單則引導使用者回網站重新產生綁定碼。

## 6. 本輪不做

依 [`docs/stream/line-n8n-order-status-mvp-plan.md`](../../stream/line-n8n-order-status-mvp-plan.md) 定案：

- LINE Login／LIFF、解除綁定。
- 查詢最近多筆訂單或任意欄位查詢。
- Booking 預約的 LINE 詢問（維持原本官方帳號連結，未接綁定碼流程）。
- 主動訂單狀態事件推播、修改收件資訊、修改付款方式。

## 7. 驗證結果

人工 Swagger 驗證步驟見 [`line-n8n-order-status-swagger-validation.md`](../test/line-n8n-order-status-swagger-validation.md)。
