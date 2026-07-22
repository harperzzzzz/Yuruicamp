# Checkout Request 手動驗證

## 用途

確認 Checkout 頁只透過共用 facade 送出後端允許的建立欄位，不再送會員、價格或訂單快照。

### 瀏覽器驗證流程

測試前確認：

- 從 `frontend/` 執行 `npm run dev`。
- 購物車已有包含 `variantId` 的商品。
- 要測真後端時，Spring Boot 已啟動且會員已登入。

#### 1. 開啟 Checkout

進入：

```text
/storefront/pages/checkout.html
```

填寫收件姓名、電話、地址與付款方式。

#### 2. 檢查 Request

開啟瀏覽器 DevTools 的 Network，按下「確認結帳」，查看：

```http
POST /api/checkout/sessions
```

Request Body 只能包含：

```json
{
  "items": [{ "variantId": "V001", "quantity": 1 }],
  "shipping": {
    "recipientName": "Amy",
    "phone": "0912345678",
    "address": "台北市信義區測試路 1 號"
  },
  "paymentMethod": "cod",
  "idempotencyKey": "第一次送出由 crypto.randomUUID() 產生"
}
```

不可出現 `customerId`、商品名稱、SKU、單價、subtotal、運費、折扣、total、訂單狀態、付款狀態或點數。

#### 3. 檢查網路失敗重試

在 DevTools 的 Application → Session Storage 記下：

```text
checkoutIdempotencyKey
```

暫時切換 Network 為 Offline 後送出，再恢復 Online 重試。預期兩次使用相同 key，不會因失敗產生新 UUID。

#### 4. 檢查連點與成功狀態

快速連點「確認結帳」時，前端應共用同一個 Promise 與 key。成功後 Session Storage 應保存：

```text
checkoutCompletedOrderId
lastCheckoutSession
```

預期同一份購物車不會再次呼叫建立 API。

#### 5. 檢查購物車變更

修改購物車商品規格或數量。預期舊的 `checkoutIdempotencyKey` 與 `checkoutCompletedOrderId` 被清除；下一次送出產生新的 UUID。

#### 6. 檢查取消與逾時

執行 `API.checkout.cancelSession(orderId)` 成功後，或 API 回傳 `CHECKOUT_EXPIRED` 後，預期以下四個 key 都不存在：

```text
checkoutIdempotencyKey
checkoutCartFingerprint
checkoutCompletedOrderId
```

#### 7. 檢查後端回應

預期回傳 `CheckoutSession`，商品快照與 `pricing` 應來自後端；頁面把完整 Session 暫存在 `sessionStorage.lastCheckoutSession`，並以後端 `pricing` 覆蓋摘要。I-7 完成前不前往成功頁，而是在原頁顯示等待 ECPay／COD 下一步。

#### 8. 執行自動檢查

```powershell
cd frontend
npm run test:checkout-request
```

預期顯示：

```text
Checkout Request contract checks passed
```

此驗證是必要的，因為每次重試若產生新 key，後端可能建立多張訂單與多筆庫存保留；穩定 key 才能讓後端冪等規則生效。
