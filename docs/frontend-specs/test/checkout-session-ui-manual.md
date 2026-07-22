# Checkout I-6 Session UI 手動驗證

## 用途

確認商城 Checkout 的 Draft、Ready、Expired、Cancelled、倒數與錯誤提示都以後端 Session 為主。

### Swagger／前端驗證流程

1. 啟動 PostgreSQL、Spring Boot 與前端 Vite，設定 `USE_MOCK_API: false`，並準備有效會員 Token 與含 `V001` 的購物車。
2. 開啟 `/storefront/pages/checkout.html`，填妥資料後按「確認結帳」。
3. 確認 Ready 面板顯示 `CheckoutSession.pricing`、Session 編號與 `checkoutExpiresAt` 倒數；頁面不跳成功頁。
4. 按「取消 Checkout」，確認 Network 出現 `POST /api/checkout/sessions/{orderId}/cancel`，Session Storage 的 Checkout keys 被清除，購物車內容仍在且 Drawer 開啟。
5. 建立新的 Checkout 後等待期限歸零，或在開發環境將 `lastCheckoutSession.checkoutExpiresAt` 改成過去時間再重新整理。確認畫面顯示「保留庫存已釋放」，並可重新建立 Checkout。

### Draft／PATCH 驗證

在 Checkout 頁的 Console 以 facade 建立缺少收件資料的 Session：

```javascript
API.checkout.createSession({
  items: [{ variantId: 'V001', quantity: 1 }],
  shipping: null,
  paymentMethod: null,
  idempotencyKey: crypto.randomUUID(),
}).then(session => {
  sessionStorage.setItem('lastCheckoutSession', JSON.stringify(session));
  sessionStorage.setItem('checkoutCompletedOrderId', session.orderId);
  location.reload();
});
```

1. 確認顯示 Draft 與「資料尚未完整」，購物車沒有被清空。
2. 補齊收件資料與付款方式後按「更新結帳資料」。
3. 確認 Network 使用 `PATCH /api/checkout/sessions/{orderId}`，回應變成 `ready_to_pay` 後才開始倒數。

### 錯誤對照

| 後端 code | 預期畫面與操作 |
|-----------|----------------|
| `UNAUTHORIZED` | 顯示請先登入並開啟登入 Modal |
| `STOCK_INSUFFICIENT` | 顯示缺貨 variant，提供返回購物車 |
| `VALIDATION_ERROR` | 顯示 details 並標記對應欄位 |
| `IDEMPOTENCY_CONFLICT`／冪等 `CONFLICT` | 清除舊 key，按鈕改為重新建立 Checkout |
| `CHECKOUT_EXPIRED` | 停止倒數、清除 Session、保留購物車 |
| `INTERNAL_ERROR` | 顯示稍後再試，不自行改寫訂單狀態 |

### 自動驗證

```powershell
cd frontend
npm run test:checkout-session-ui
npm run test:checkout-backend
npm run smoke
```

這項驗證是必要的，因為 Checkout 的價格、庫存保留與期限都由後端掌管；前端只能呈現後端狀態並提供安全的下一步，不能自行把訂單改成成功或已付款。
