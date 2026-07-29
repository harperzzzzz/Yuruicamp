# Checkout Session Read Swagger 驗證

## 1. 前置條件

- PostgreSQL 已啟動並套用最新 Schema 與開發 seed。
- Spring Boot 已啟動。
- 本機使用 `FIREBASE_ENABLED=false`。
- 開啟 `http://localhost:8080/swagger-ui.html`。

## 2. 建立會員 Session

先執行：

```http
POST /api/auth/firebase/session
```

Request Body：

```json
{
  "idToken": "dev:uid-c2:c2@example.com:google:C2Tester"
}
```

回傳 HTTP `200` 後，按 Swagger 的 `Authorize` 並輸入：

```text
dev:uid-c2:c2@example.com:google:C2Tester
```

## 3. 建立可讀取的 Checkout

執行：

```http
POST /api/checkout/sessions
```

使用新的 `idempotencyKey`：

```json
{
  "items": [
    {
      "variantId": "V001",
      "quantity": 1
    }
  ],
  "paymentMethod": "ecpay-credit",
  "shipping": {
    "recipientName": "Checkout Read 測試",
    "phone": "0912345678",
    "address": "台北市測試路 1 號"
  },
  "idempotencyKey": "swagger-checkout-read-001"
}
```

記下回應的 `orderId`。

## 4. 讀取本人 Checkout

執行：

```http
GET /api/checkout/sessions/{orderId}
```

預期：

- HTTP `200`。
- `orderId` 與建立時相同。
- `paymentStatus=unpaid`。
- `pricing`、`items`、`shipping`、`couponClaimId` 與 `checkoutExpiresAt` 為後端最新快照。
- GET 不會延長 `checkoutExpiresAt`，也不會修改訂單或庫存保留狀態。

## 5. 驗證未登入

在 Swagger 按 `Logout` 後再次呼叫相同 GET。

預期：

- HTTP `401`。
- `error.code=UNAUTHORIZED`。

## 6. 驗證非本人與不存在

使用另一位會員登入後讀取步驟 3 的 `orderId`，或使用 `UNKNOWN`：

```http
GET /api/checkout/sessions/UNKNOWN
```

預期：

- HTTP `403`。
- `error.code=FORBIDDEN`。

兩種情況使用相同錯誤，避免透露其他會員 Checkout 是否存在。

## 7. 驗證更新後重新讀取

重新登入原會員，先 PATCH 收件資料或付款方式，再呼叫 GET。

預期 GET 回傳更新後資料，商品與價格快照保持不變。

## 8. 為什麼需要驗證

Checkout 頁面重新整理、付款返回頁與成功頁都可能遺失記憶體中的 Session，因此必須能從後端重新取得最新快照。本人限制可避免收件地址與訂單資訊外洩；確認 GET 不會延長期限或修改保留帳，則能避免單純重新整理意外延長庫存占用。
