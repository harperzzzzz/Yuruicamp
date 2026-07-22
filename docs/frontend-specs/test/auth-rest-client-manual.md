# 前端認證與 REST 手動驗證

## 驗證流程

1. 啟動 PostgreSQL 與 Spring Boot，確認 `http://localhost:8080/api/health` 正常。
2. 在 `frontend/` 執行 `npm run dev`，開啟任一有載入 `api-mock.js` 的主站頁面。
3. 在瀏覽器 Console 建立只供本次頁面使用的開發 Token：

   ```javascript
   const devToken = 'dev:frontend-it:frontend-it@example.com:google:FrontendIT';
   AppAuth.configure({ devToken });
   ```

4. 建立／綁定後端會員 session：

   ```javascript
   await API._restRequest('/auth/firebase/session', {
     method: 'POST',
     auth: 'none',
     body: { idToken: devToken },
   });
   ```

5. 驗證會員請求與 Envelope 解包：

   ```javascript
   await API._restRequest('/me', { auth: 'required' });
   ```

   結果應直接是會員 `data`，不是包含 `success` 的整層 Envelope。Network 面板中的 `/me` 應帶有 `Authorization: Bearer dev:...`。

6. 驗證分頁 meta：

   ```javascript
   await API._restRequest('/products?page=0&size=1&sort=id,asc', {
     auth: 'optional',
     includeMeta: true,
   });
   ```

   結果應包含 `data` 與 `meta`。

7. 驗證後端錯誤轉換：

   ```javascript
   try {
     await API._restRequest('/products?page=-1', { auth: 'none' });
   } catch (error) {
     console.log(error.name, error.code, error.message, error.details, error.status);
   }
   ```

   錯誤名稱應為 `ApiRequestError`，並保留後端錯誤碼與 HTTP status。

8. 驗證結束後清除記憶體中的 Token：

   ```javascript
   AppAuth.configure({ devToken: '' });
   ```

9. **FA-2（可選）**：模擬登入失效（需已載入 auth／modal）：

   ```javascript
   ApiClient.notifySessionExpired();
   ```

   商城／預約：應出現 toast「登入已過期」、登入 Modal 開啟，且本機登入狀態被清掉。  
   後台頁：應導向 `/admin/login.html`。

這項手動驗證可確認瀏覽器、CORS、Bearer Header、後端 Envelope 與錯誤格式真的串通；Node 測試則負責穩定驗證 Firebase Token、dev Token、URL、body 與錯誤物件，兩者用途不同且都需要保留。
