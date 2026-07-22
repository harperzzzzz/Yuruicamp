# Checkout API Facade

## 用途

`window.API.checkout` 是 Checkout 頁面的唯一業務入口。Facade 依 `USE_MOCK_API` 選擇契約一致的 Checkout Mock adapter 或 `ApiClient._restRequest()`，頁面不處理兩種資料形狀。

## 方法與路徑

| 方法 | HTTP | Adapter path |
|------|------|--------------|
| `createSession(request)` | POST | `/checkout/sessions` |
| `getSession(orderId)` | GET | `/checkout/sessions/{orderId}` |
| `updateSession(orderId, request)` | PATCH | `/checkout/sessions/{orderId}` |
| `cancelSession(orderId)` | POST | `/checkout/sessions/{orderId}/cancel` |
| `confirmCod(orderId)` | POST | `/checkout/sessions/{orderId}/confirm-cod` |
| `createEcpayForm(orderId)` | POST | `/checkout/sessions/{orderId}/ecpay` |

`AppConfig.API_BASE_URL` 已包含 `/api`，因此 adapter path 不得再寫 `/api/checkout/...`。`orderId` 會先檢查非空，再使用 `encodeURIComponent()` 放入路徑。

## 目前邊界

- Mock 與 Backend 的 `createSession()` 都回完整 `CheckoutSession`。
- Mock 金額只讀商品契約價格，忽略 Request 內的價格與總額。
- Mock Checkout 使用獨立 `mockCheckoutSessions`，不寫入 Legacy `mockOrders`。
- 相同會員與冪等鍵的相同 Request 會回放；內容不同會回 `CONFLICT`。
- 後端已實作：建立、讀取、更新、COD 確認、取消。
- `getSession()` 可供重新整理、跨頁導向與付款返回後恢復最新 Session，不延長 Checkout 期限。
- `confirmCod()` 成功回傳 `checkoutStep=completed` 與 `checkoutExpiresAt=null`；付款狀態仍是 `unpaid`。
- 等待 Payment 線 D：建立 ECPay 表單、Notify 驗簽與付款落帳。
- Mock 支援 COD 成立狀態；ECPay 仍明確回 `PAYMENT_NOT_IMPLEMENTED`。
- Checkout 頁面已改用 `API.checkout.createSession()`，不再呼叫 Legacy `orders.create()`。

## 建立 Request

Checkout 頁面只送後端允許的欄位：

```json
{
  "items": [{ "variantId": "V001", "quantity": 1 }],
  "shipping": {
    "method": "delivery",
    "recipientName": "Amy",
    "phone": "0912345678",
    "address": "台北市信義區測試路 1 號",
    "pickupBranchId": null
  },
  "paymentMethod": "cod",
  "idempotencyKey": "瀏覽器產生的唯一值"
}
```

- 不送 `customerId`；會員由 Firebase Bearer Token 的 principal 決定。
- 不送商品名稱、SKU、價格、金額、訂單狀態、付款狀態或點數。
- 商品快照與全部金額由 Spring Boot 從 PostgreSQL 重新建立。
- 第一次送出使用 `crypto.randomUUID()`，並將 key 暫存在 `sessionStorage.checkoutIdempotencyKey`。
- 網路失敗重試與連點確認沿用同一個 key；連點也共用同一個前端 Promise。
- 建立成功保存 `checkoutCompletedOrderId`，同一份購物車不再呼叫建立 API。
- 購物車規格或數量變更時，立即清除舊 key 與舊 orderId；下一次送出再產生新 UUID。
- `cancelSession()` 成功或收到 `CHECKOUT_EXPIRED` 時清除整組冪等狀態。
- 優惠券尚待 F-2，不放入建立 Request，也不在前端標記為已使用。
- 建立成功後，頁面摘要必須採用回傳的 `pricing`；前端金額只供送出前預估。
- Backend 模式的優惠券輸入停用，不可用前端折扣覆蓋 `pricing`。
- `ecpay-credit` 不收集卡號、到期日或 CVV；I-7 才呼叫 `createEcpayForm()` 並導向付款頁。

使用的 sessionStorage key：

| Key | 用途 |
|-----|------|
| `checkoutIdempotencyKey` | 傳給後端的 UUID |
| `checkoutCartFingerprint` | 判斷購物車規格或數量是否改變 |
| `checkoutCompletedOrderId` | 建立成功後阻止再次建立 |
| `lastCheckoutSession` | 目前分頁暫存完整 Session 與後端 pricing |

頁面應呼叫 `API.checkout.*`，不可自行呼叫 `_restRequest()` 或 `fetch()`。`API._restRequest` 只保留給基礎驗證與其他 facade 建置。

Legacy `API.orders.create()` 暫時保留給尚未遷移的 Mock 頁面；`USE_MOCK_API=false` 時會直接回 `LEGACY_ORDER_CREATE_DISABLED`，避免靜默寫入 `mockOrders`。

## Checkout 狀態與錯誤

- `checkoutStep=draft`：頁面保留購物車，讓使用者補資料後呼叫 `updateSession()`。
- `checkoutStep=ready_to_pay`：頁面顯示後端 pricing，並依 `checkoutExpiresAt` 顯示倒數。
- COD 建立或更新後若回傳 `ready_to_pay`，頁面會在同一次「確認結帳」操作中立即呼叫 `confirmCod()`；使用者不需要再次確認。
- `checkoutStep=completed`：目前表示 COD 已確認成立；成功頁顯示貨到付款，不宣稱已付款。
- 主動取消：呼叫 `cancelSession()`，清除 Session 後開啟共用購物車 Drawer。
- `CHECKOUT_EXPIRED`：停止倒數、清除冪等鍵與 orderId，保留購物車供重新建立。
- `UNAUTHORIZED`、`STOCK_INSUFFICIENT`、`VALIDATION_ERROR`、`IDEMPOTENCY_CONFLICT`、`CHECKOUT_EXPIRED`、`INTERNAL_ERROR` 都由頁面轉為明確操作。
- 商城後端目前也可能以 `CONFLICT` 搭配 idempotency 訊息回傳衝突；頁面會相容轉為 `IDEMPOTENCY_CONFLICT` 流程。
