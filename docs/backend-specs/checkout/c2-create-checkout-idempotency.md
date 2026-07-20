# C-2 建立 Checkout

## 用途

建立待付款訂單，避免重複建單，並處理空白資料。

## 流程

```text
檢查請求
→ 合併相同商品
→ 產生請求指紋
→ 鎖定會員資料
→ 用會員與冪等鍵查訂單
   ├─ 內容相同：回傳原訂單
   ├─ 內容不同：回傳 409
   └─ 沒有訂單：建立訂單與庫存保留
```

## 規則

- `idempotencyKey` 必填，最多 `128` 字元。
- 商品至少一筆，數量必須大於 `0`。
- 空 Body 或錯誤 JSON 回傳 `400`。
- 收件資料不足時使用 `PENDING_CHECKOUT`，訂單保持草稿狀態。
- 建立 Checkout 時使用會員列悲觀寫入鎖，讓同一會員的請求依序處理。
- 資料庫使用 `UNIQUE (customer_id, checkout_idempotency_key)` 防止重複建單。

## 會員列悲觀鎖

`CustomerRepository.findByIdForCheckout()` 使用 `PESSIMISTIC_WRITE` 鎖住會員資料列。
當同一位會員同時送出多個 Checkout 請求時，只有第一個交易可以繼續，其他交易必須等待鎖釋放。

```text
請求 A 與請求 B 同時進入
→ 請求 A 取得會員列鎖
→ 請求 B 等待
→ 請求 A 查詢冪等鍵並建立訂單
→ 請求 A 提交交易並釋放鎖
→ 請求 B 取得會員列鎖
→ 請求 B 查到原訂單並直接回傳
```

悲觀鎖負責讓同一會員的請求依序執行；資料庫唯一限制則是最後一道防護。

## 併發驗證流程

Swagger 適合驗證一般重送，但無法穩定製造真正的同時請求。併發測試分成「API 行為驗證」與「資料庫鎖驗證」。

### 測試一：API 併發冪等驗證

#### 前置條件

1. PostgreSQL 與後端已啟動。
2. `FIREBASE_ENABLED=false`，可以使用開發 Token。
3. 已呼叫 `POST /api/auth/firebase/session` 建立測試會員。
4. `V001` 是啟用中的商品規格，而且至少有 `1` 件可用庫存。
5. 每次測試都使用從未使用過的 `idempotencyKey`。

測試 Token：

```text
dev:uid-c2-concurrent:c2-concurrent@example.com:google:C2Concurrent
```

測試 Payload：

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
    "recipientName": "王小明",
    "phone": "0912345678",
    "address": "台北市信義區測試路 1 號"
  },
  "idempotencyKey": "c2-concurrent-唯一測試值"
}
```

#### 執行步驟

1. 建立兩個執行緒或非同步工作。
2. 讓兩個工作先等待同一個起跑訊號。
3. 同時使用相同會員 Token、相同 Payload 與相同 `idempotencyKey` 呼叫 `POST /api/checkout/sessions`。
4. 等待兩個請求都完成，保存 HTTP 狀態碼與 Response Body。
5. 比對兩個回應中的 `data.orderId`。
6. 使用會員 ID 與 `idempotencyKey` 查詢 `orders`。
7. 使用 `orderId` 查詢 `order_items` 與 `product_stock_reservations`。

## 驗證結果

- 相同請求重送會回傳相同訂單。
- 相同鍵搭配不同內容會回傳 `409`。
- 空白冪等鍵會回傳 `400`。
- Hibernate Schema 驗證通過。
- Maven 完整測試 `19` 個通過，包含 PostgreSQL 冪等回放驗證。
- C-2 已完成。


### Swagger 驗證 (Checkout，POST /api/checkout/sessions)

1. swagger 右上角有一個綠色按鈕Authorize 點它
- 輸入 dev:uid-c2:c2@example.com:google:C2Tester

2. Checkout ，建立訂單
- POST /api/checkout/sessions
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
    "recipientName": "王小明",
    "phone": "0912345678",
    "address": "台北市信義區測試路 1 號"
  },
  "idempotencyKey": "swagger-c2-test-001"
}
```

- 驗證結果:
   - HTTP 200 成功
   - HTTP 409 庫存不足 或 Checkout 找不到任何門市庫存
```json
{
  "success": true,
  "data": {
    "orderId": "訂單編號",
    "paymentStatus": "unpaid",
    "paymentMethod": "ecpay-credit",
    "status": "pending",
    "checkoutExpiresAt": "到期時間",
    "pricing": {
      "subtotal": "3200.00",
      "shippingFee": "0.00",
      "discount": "0.00",
      "total": "3200.00"
    },
    "items": [
      {
        "variantId": "V001",
        "quantity": 1
      }
    ],
    "shipping": {
      "recipientName": "王小明",
      "phone": "0912345678",
      "address": "台北市信義區測試路 1 號"
    },
    "checkoutStep": "ready_to_pay"
  }
}
```

3. Checkout，POST /api/checkout/sessions/{orderId}/cancel
- orderId 填入 Of9eac02b34734941854d6b90cb4fe72，回傳Http 200
