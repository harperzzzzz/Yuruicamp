# Booking 共用腳本（Core Scripts）

**狀態：** Implemented（2026-07-22）  
**目的：** 所有預約頁都有 `window.AppConfig`（含 `API_BASE_URL`），避免登入／REST 打錯網域。

---

## 為什麼需要

Booking 各頁 HTML **各自列出 script**，不會像 React 那樣自動共用。  
先前 `rental-guide`／`booking-faq`／`booking-cart`／`booking-success` 未載入 `config.js`，導致：

- `window.AppConfig === undefined`
- Firebase 仍可能初始化（`layout.js` 有載）
- `POST /auth/firebase/session` 的 base URL 變成空字串，請求打到 Vite 而非 Spring

商城 `storefront/pages/*` 每頁都有 `config.js`，無此問題。

---

## 單一真相來源

| 檔案 | 角色 |
|------|------|
| [`frontend/booking/partials/booking-core-scripts.partial`](../../frontend/booking/partials/booking-core-scripts.partial) | 清單文件（給人看／對照） |
| [`frontend/booking/js/booking-core-scripts.js`](../../frontend/booking/js/booking-core-scripts.js) | 頁面用：**同步** `document.write` 注入 |
| [`frontend/booking/js/layout.js`](../../frontend/booking/js/layout.js) → `loadBookingCoreScripts()` | `loadBookingSharedLayout()` 內安全網（`loadScriptOnce`） |

### 目前注入順序（不可亂）

1. `/storefront/js/config.js` → `window.AppConfig`
2. `/storefront/js/api-client.js` → `window.AppAuth`／`window.ApiClient`（須在 api-mock／booking-api 之前）
3. `/storefront/js/formatters.js`
4. `/storefront/js/api-mock.js` → `window.API`
5. `/storefront/js/booking-api.js` → `BookingAPI`

Firebase 就緒後由 `layout.js`／`main.js` 呼叫：

```javascript
window.AppAuth.configure({ auth: window.YuruiFirebase.getAuth() });
```

讓 `ApiClient` 自動帶 Bearer；登入 UI（`auth.js`）也走同一套 `AppAuth`／`ApiClient`。

---

## 頁面怎麼寫

在 `layout.js` 之後、**頁面專屬 JS 之前**加一行：

```html
<script src="/booking/js/layout.js"></script>
<!-- 共用：config／api-client／formatters／api-mock／booking-api（見 booking/partials/booking-core-scripts.partial） -->
<script src="/booking/js/booking-core-scripts.js"></script>
<!-- … jquery／CDN／頁面 JS … -->
```

已套用頁面：`camp-rental`、`camp-search`、`camp-detail`、`camp-rental`、`booking-cart`、`booking-checkout`、`booking-success`、`booking-faq`、`rental-guide`、`member-center`。

---

## 新增共用腳本時

1. 改 `booking/partials/booking-core-scripts.partial`
2. 改 `booking/js/booking-core-scripts.js` 的陣列（含 flag 名稱）
3. 改 `layout.js` 的 `loadBookingCoreScripts()` 陣列（同一組 flag）
4. 更新本文件表格

---

## 驗收

1. 開 `booking/pages/rental-guide.html` → Console：`window.AppConfig?.API_BASE_URL` 應為 `http://localhost:8080/api`
2. 同頁 Google／LINE 登入 → Network session 打到 `localhost:8080`
3. 商城頁行為不變（本改動只動 booking）
