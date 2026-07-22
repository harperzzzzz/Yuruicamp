# Checkout Mock 契約手動驗證

## 驗證流程

1. 在 `frontend/` 執行 `npm run dev`，開啟任一主站頁面。
2. 在 Console 切到 Mock 並清除上一輪 Checkout Session：

   ```javascript
   AppConfig.USE_MOCK_API = true;
   localStorage.removeItem('mockCheckoutSessions');
   ```

3. 只透過 facade 建立 Checkout：

   ```javascript
   const request = {
     items: [{ variantId: 'V001', quantity: 1, unitPrice: '0.01' }],
     paymentMethod: 'cod',
     shipping: {
       recipientName: 'Mock 收件人',
       phone: '0912345678',
       address: '台北市測試路 1 號',
     },
     idempotencyKey: `mock-${crypto.randomUUID()}`,
   };
   const session = await API.checkout.createSession(request);
   session;
   ```

4. 確認結果：

   - `paymentStatus` 是 `unpaid`。
   - `checkoutStep` 是 `ready_to_pay`。
   - `pricing.subtotal` 與 `pricing.total` 是 `3200.00`，不採用偽造的 `0.01`。
   - `items[]`、`shipping`、`couponClaimId` 都存在。
   - `checkoutExpiresAt` 約為目前時間加 15 分鐘。

5. 使用同一個 Request 重送：

   ```javascript
   const replay = await API.checkout.createSession(request);
   console.log(replay.orderId === session.orderId);
   ```

   應為 `true`。同一冪等鍵改成不同數量時應收到 `CONFLICT`。

6. 更新、讀取與取消：

   ```javascript
   await API.checkout.updateSession(session.orderId, {
     shipping: { address: '新北市更新路 2 號' },
     paymentMethod: 'ecpay-credit',
     couponClaimId: null,
   });
   await API.checkout.getSession(session.orderId);
   await API.checkout.cancelSession(session.orderId);
   ```

7. 確認 Checkout 沒有寫入 Legacy Order：

   ```javascript
   console.log(localStorage.getItem('mockOrders'));
   console.log(localStorage.getItem('mockCheckoutSessions'));
   ```

   `mockCheckoutSessions` 應有資料；本次流程不應新增 `mockOrders`。

8. 執行自動契約驗證：

   ```powershell
   cd frontend
   npm run test:checkout-mock
   ```

9. 驗證完恢復專案設定：

   ```javascript
   AppConfig.USE_MOCK_API = false;
   ```

手動驗證可確認頁面執行環境、localStorage 與 Mock 商品資料真的串通；自動測試則固定檢查完整欄位、後端價格、冪等、更新、取消與 Backend 模式封鎖 Legacy Order，避免兩種模式再次分裂。
