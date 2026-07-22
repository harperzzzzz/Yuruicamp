# Checkout Session 重新讀取網頁驗證

## 1. 前置條件

- 後端與 PostgreSQL 已啟動。
- 前端使用 Backend 模式並以 `npm.cmd run dev` 啟動。
- 已登入 Firebase 會員。
- 購物車至少有一項可售商品。

## 2. 驗證 facade 請求

1. 開啟 Checkout 頁並建立 Checkout Session。
2. 開啟 DevTools → Network，勾選 `Preserve log`。
3. 在 Console 執行：

```javascript
await window.API.checkout.getSession(
  sessionStorage.getItem("checkoutCompletedOrderId"),
);
```

若目前頁面使用 `lastCheckoutSession` 保存 ID，改取該物件的 `orderId` 後傳入。

預期：

- 發出 `GET /api/checkout/sessions/{orderId}`。
- Request Headers 有 `Authorization: Bearer ...`。
- Response 為完整 `CheckoutSession`。
- 路徑沒有重複 `/api/api`。

## 3. 驗證重新讀取內容

比對建立 Checkout 與 GET Response：

- `orderId` 相同。
- `pricing` 與商品快照相同。
- PATCH 過的 `shipping` 與 `paymentMethod` 使用最新值。
- `checkoutExpiresAt` 不因 GET 延長。
- GET 不新增第二張訂單。

## 4. 驗證登入與本人限制

- 登出後呼叫：預期 HTTP `401`，頁面不得改讀 Mock Checkout。
- 換另一位會員使用原 `orderId`：預期 HTTP `403`。
- 使用不存在 ID：預期 HTTP `403`。

## 5. 驗證逾時或取消狀態

取消 Checkout 或等待後端逾時處理後，再呼叫 GET。

預期：

- Response `status=cancelled`。
- 保留原本 `checkoutExpiresAt` 供畫面判斷。
- 前端不得顯示可付款狀態，也不得自行把訂單改回有效。

## 6. 為什麼需要驗證

重新整理、跨頁導向與付款服務返回都可能讓前端暫存遺失。這項驗證確保頁面能以後端 Checkout Session 恢復畫面，並確認登入、本人限制、期限與價格仍以伺服器資料為準，不會退回 Mock 或前端自行推測付款狀態。
