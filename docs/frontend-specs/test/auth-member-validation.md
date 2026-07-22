# 前端認證與會員實際驗證

## 1. 開發 Token 路徑

開啟任一已載入 `config.js`、`api-client.js` 與 `api-mock.js` 的商城頁，在 Console 執行：

```javascript
window.frontendValidationToken =
  'dev:frontend-validation:frontend-validation@example.test:google:FrontendValidation';

AppAuth.configure({ devToken: window.frontendValidationToken });

const session = await ApiClient._restRequest('/auth/firebase/session', {
  method: 'POST',
  auth: 'none',
  body: { idToken: window.frontendValidationToken },
});

const me = await ApiClient._restRequest('/me', { auth: 'required' });
console.log(session, me);
```

預期：

- 兩個請求都打到 `http://localhost:8080/api/**`。
- `/auth/firebase/session` 不帶 Bearer；`/me` 帶 Bearer。
- 回傳值是 Envelope 的 `data`，不是整層 `{ success, data }`。
- `session.customerId` 與 `me.id` 對應同一會員。

驗證錯誤物件：

```javascript
try {
  await ApiClient._restRequest('/products?page=-1', { auth: 'none' });
} catch (error) {
  console.log(error.name, error.code, error.message, error.status, error.details);
}
```

預期為 `ApiRequestError`，並保留後端 `VALIDATION_ERROR` 與 HTTP `400`。

完成後清除本頁 dev Token：

```javascript
AppAuth.configure({ devToken: '' });
```

## 2. 真 Firebase 路徑

1. 依 `frontend/.env.example` 建立未追蹤的 `.env.local`，填入 `VITE_FIREBASE_*`。
2. 後端設定 `FIREBASE_ENABLED=true`、`FIREBASE_CREDENTIALS`、`FIREBASE_PROJECT_ID`；三者 project ID 必須一致。
3. 重啟前後端，使用 Google 或已設定的 Provider 登入。
4. 確認 Firebase popup 完成後，前端先呼叫 `/api/auth/firebase/session`，再呼叫 `/api/me`。
5. 重新整理頁面，等待 `YuruiFirebase.waitForAuthState()` 後仍可取得會員資料。
6. 登入後依序開啟會員中心、Checkout 與 Booking 頁，確認頁面首批 API 會等待 `AppAuth.whenReady()`，不會出現 `AUTH_TOKEN_UNAVAILABLE` 或再次要求登入。

Console 非敏感檢查：

```javascript
typeof window.YuruiFirebase;
typeof window.AppAuth;
typeof window.ApiClient;
typeof window.YuruiApiHttp;
await window.AppAuth.whenReady();
```

前三者應存在，`YuruiApiHttp` 應為 `undefined`。正式 REST 不得讀取自建 localStorage Token。

## 3. 401 與登入失效

先執行：

```powershell
npm run test:api-client
```

此測試需證明第一次 `401` 會呼叫 Firebase `getIdToken(true)` 並只重送一次。瀏覽器可再執行：

```javascript
ApiClient.notifySessionExpired();
```

商城／Booking 應清除 UI 登入狀態、顯示登入逾期並開啟登入入口；Admin 應導回 `/admin/login.html`。

## 4. 會員資料與隔離

- Booking 列表必須呼叫 `GET /api/booking/bookings?page=0&size=20`，不能傳 `customerId`。
- 第二位會員讀取第一位會員的 Booking 詳情，預期 `404 NOT_FOUND`，不得以 `403` 洩漏資料存在。
- Coupon 列表使用 `GET /api/me/coupons`；領券使用 `POST /api/me/coupons/claims`。
- 會員訂單 Controller 與 `API.orders` Backend 分流已完成；驗收時必須確認 Network 呼叫 `/api/me/orders`，若仍從 `orders.json` 顯示資料只能標記為 Mock。

## 5. 通過標準

- Firebase／dev Token 都只經 `AppAuth` 與 `ApiClient`。
- Bearer、CORS、Envelope 與錯誤物件符合預期。
- Reload 後 Firebase currentUser 可還原；dev Token 只限 development 與目前分頁。
- 站內導頁後，頁面 API 即使早於 Firebase 注入也會等待 Auth Ready，不會清除既有登入。
- Token 過期只刷新重試一次，第二次失敗回登入。
- 會員只能讀自己的資料，前端無 `U001` 或固定會員 fallback。

## 6. 首次登入與會員資料

1. 使用尚未建立 `customers` 資料的 Firebase 帳號，分別從商城與 Booking 登入。
2. `POST /api/auth/firebase/session` 回傳 `created=true` 時才應開啟 `#personalizationModal`；登出後再次登入同一帳號，回傳 `created=false`，不得再次開啟。
3. 首次登入若關閉偏好問卷，`AppState.preferences`、`localStorage.preferences` 與 `yurui_profile.preferences` 都應為 `null`，不得自動選擇任何風格或裝備。
4. 完成兩步偏好設定後，頁面應導向 `/storefront/pages/member-center.html?onboarding=profile`，自動開啟「會員資料」並提示先完成資料。
5. `#profileEmail` 與 `#profileBirthday` 必須可編輯；儲存時 Email 必須通過格式驗證，生日不得晚於今天往前 18 年的日期。
6. `#cardSince` 必須顯示後端 Session 的 `registeredAt` 日期，且既有會員重新登入時不得改成當天日期。
7. 在 `frontend/` 執行 `npm run test:first-login`，預期 exit code 為 `0`。
