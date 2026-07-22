# Checkout Facade 前端手動驗證

## 驗證流程

1. 啟動 PostgreSQL、Spring Boot 與前端 Vite，並確認開發 Seed 已提供 `V001` 庫存。
2. 開啟主站頁面，在 Console 設定本次頁面使用的開發 Token：

   ```javascript
   const devToken = 'dev:checkout-front:checkout-front@example.com:google:CheckoutFront';
   AppAuth.configure({ devToken });
   ```

3. 建立／綁定後端會員：

   ```javascript
   await API._restRequest('/auth/firebase/session', {
     method: 'POST',
     auth: 'none',
     body: { idToken: devToken },
   });
   ```

4. 建立 Checkout：

   ```javascript
   const session = await API.checkout.createSession({
     items: [{ variantId: 'V001', quantity: 1 }],
     couponClaimId: null,
     paymentMethod: null,
     shipping: null,
     idempotencyKey: `frontend-${crypto.randomUUID()}`,
   });
   session;
   ```

   應直接取得 `CheckoutSession` data。Network URL 應為 `http://localhost:8080/api/checkout/sessions`，不得出現 `/api/api/`。

5. 使用回傳的 `orderId` 更新 Checkout：

   ```javascript
   const updated = await API.checkout.updateSession(session.orderId, {
     shipping: {
       recipientName: '前端測試',
       phone: '0912345678',
       address: '台北市信義區測試路 1 號',
     },
     paymentMethod: 'cod',
     couponClaimId: null,
   });
   updated;
   ```

6. 取消並確認後端回傳取消後 Session：

   ```javascript
   await API.checkout.cancelSession(session.orderId);
   ```

7. 六個方法的路徑、HTTP method、Bearer 要求、body 與 orderId 編碼可執行：

   ```powershell
   cd frontend
   npm run test:checkout-facade
   ```

目前不要把 `getSession()`、`confirmCod()`、`createEcpayForm()` 的 404 當成前端 facade 失敗：GET Controller 尚未建立，後兩個端點等待線 D。手動驗證的必要性在於確認瀏覽器實際使用正確 base URL、Bearer、CORS 與 Envelope；Node 測試則確保尚未實作的後端端點仍已使用正確契約路徑。
