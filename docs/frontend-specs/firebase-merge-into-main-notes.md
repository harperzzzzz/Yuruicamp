# Firebase 合併進 main 後：協作者注意事項

**對象：** 合併 PR（`firebase` → `main`，例如 [#39](https://github.com/kobishi0401/Yuruicamp/pull/39)）之後，繼續在 `main` 開發的所有人  
**狀態：** 生效中（合併後請先讀這份）  
**最後更新：** 2026-07-22  
**相關 PR／分支：** `firebase` 已先把 `origin/main` merge 進來，再以 **B 方案**接線（保留 main 的 `AppAuth` + `ApiClient`，Firebase 掛上去）

---

## 1. 先用一句話搞懂

合併後 **main 的 HTTP／認證主幹沒有被換成另一套**：

```text
頁面／Facade（API、BookingAPI、AdminAPI）
    → ApiClient._restRequest()     ← main 正式入口（請繼續用這個）
    → AppAuth.getIdToken()         ← 正式從 Firebase currentUser 取 token
    → Spring Boot
```

Firebase 登入程式（`firebase-app.js`、登入按鈕）**還在**，會在初始化後注入：

```javascript
window.AppAuth.configure({ auth: window.YuruiFirebase.getAuth() });
```

目前還有一層 **過渡期** 檔案 `api-http.js`（`YuruiApiHttp`），主要給舊的 `auth.js` 登入驗收用。  
**新功能請不要再擴充 `YuruiApiHttp`**；應走 `ApiClient`／`AppAuth`。

---

## 2. 合併後「比較安全」可以繼續做的事

這些區域大致可照原本 main 節奏開發，衝突風險較低：

| 工作類型 | 說明 |
|----------|------|
| Booking／Checkout／Coupon／Catalog **業務 API** | 後端 Controller／Service、前端 facade 繼續加方法即可 |
| Admin RBAC／Customers／Orders／Bookings 後台頁 | 只要仍透過 `AdminAPI` → `ApiClient` |
| Schema／seed／契約文件 | 與 Firebase 接線正交 |
| Mock JSON、純 UI／CSS | 不碰登入與 token 時通常無影響 |
| 在既有 facade 加 `ApiClient._restRequest` 呼叫 | 這是正確方向 |

規格入口：

- [`api/auth-rest-client.md`](./api/auth-rest-client.md)
- [`api/booking-facade.md`](./api/booking-facade.md)
- [`api/checkout-facade.md`](./api/checkout-facade.md)

---

## 3. 合併後「要特別小心」的地方（重點）

### 3.1 不要再開第二條 HTTP 水管

| 請用（正式） | 過渡／請勿擴充 |
|--------------|----------------|
| `window.ApiClient._restRequest(...)` | `window.YuruiApiHttp.apiFetch`／`fetchJson`／`fetchMe` |
| `window.AppAuth.getIdToken()`／`configure()` | 在頁面裡自己 `fetch` + 手拼 Bearer（除非文件另有規定） |

**為什麼：** 若一邊走 `ApiClient`、一邊走 `YuruiApiHttp`，之後 token、Envelope、錯誤碼會不一致，合併衝突也會再來一次。

### 3.2 Booking 共用腳本清單（最容易漏頁）

預約頁**不要**在 HTML 各自貼一整排：

```html
<!-- ❌ 不要每頁手貼 -->
<script src="/storefront/js/config.js"></script>
<script src="/storefront/js/api-client.js"></script>
...
```

**請只留：**

```html
<script src="/booking/js/layout.js"></script>
<script src="/booking/js/booking-core-scripts.js"></script>
```

若要新增／刪除 Booking 全站共用腳本，必須**同時改三處 + 文件**：

1. `frontend/booking/partials/booking-core-scripts.partial`
2. `frontend/booking/js/booking-core-scripts.js`
3. `frontend/booking/js/layout.js` → `loadBookingCoreScripts()`
4. 更新 [`booking-shared-scripts.md`](./booking-shared-scripts.md)

**目前注入順序（不可亂）：**

1. `config.js` → `AppConfig`
2. `api-client.js` → `AppAuth`／`ApiClient`（必須在 api-mock／booking-api **之前**）
3. `formatters.js`
4. `api-mock.js`
5. `booking-api.js`

漏掉 `api-client.js` 時，常見症狀：`ApiClient not loaded`、Booking REST 全掛。

### 3.3 登入／Auth UI（過渡雙軌）

相關檔案：

| 檔案 | 角色 |
|------|------|
| `frontend/storefront/js/firebase-app.js` | Firebase 初始化，`window.YuruiFirebase` |
| `frontend/storefront/js/api-client.js` | **正式** AppAuth + ApiClient |
| `frontend/storefront/js/api-http.js` | **過渡** YuruiApiHttp（登入驗收仍用） |
| `frontend/storefront/js/components/auth.js` | 登入按鈕／session／部分仍呼叫 YuruiApiHttp |
| `frontend/storefront/js/main.js` | 商城：Firebase → `AppAuth.configure` →（暫）載 api-http → auth.js |
| `frontend/booking/js/layout.js` | 預約：同上注入邏輯 |

**改登入流程前請先問／先讀：** 不要刪掉 `api-http.js` 卻沒把 `auth.js` 改完，否則 Google／LINE 登入會壞。  
後續收斂目標（另開 PR 即可）：`auth.js` 只走 `AppAuth`／`ApiClient`，再移除或薄化 `api-http.js`。

### 3.4 本機環境變數（前後端都要對齊）

**前端**（`frontend/.env.local`，可參考 `frontend/.env.example`）：

- `VITE_FIREBASE_API_KEY`
- `VITE_FIREBASE_AUTH_DOMAIN`
- `VITE_FIREBASE_PROJECT_ID`
- （以及其他 `VITE_FIREBASE_*`）

改完後需**重啟** `npm run dev`（Vite 只在啟動時讀 env）。

**後端**（見 `backend/README.md`）：

- `FIREBASE_ENABLED=true`（真驗證時）
- `FIREBASE_CREDENTIALS=...serviceAccount.json`
- `FIREBASE_PROJECT_ID=...`（建議與前端 `VITE_FIREBASE_PROJECT_ID`／service account 的 `project_id` 一致）

對應設定：`backend/.../application.properties` 的 `yuruicamp.firebase.project-id`。

### 3.5 後端安全／Session

改動下列區域時，請一併確認前端登入與 Bearer 行為：

- `FirebaseAuthenticationFilter`、`SecurityConfig`
- `POST /api/auth/firebase/session`、會員 `/api/me`
- Admin Firebase session／RBAC
- Token verifier／`YuruicampProperties` 的 Firebase projectId

不要假設「前端自己存的 localStorage token」就是唯一真相；正式 REST 應以 `AppAuth` → Firebase `getIdToken()`（或本機 `dev:`）為準。

### 3.6 Dev Token 規則（不要寫死在頁面）

- 只允許 `development` + 後端支援的 `dev:...` 格式
- 透過 `AppAuth.configure({ devToken: '...' })` 或本機 `AppConfig.AUTH.DEV_TOKEN`
- **禁止**把個人固定 token 寫進 Checkout／Booking 頁面或提交到 git

細節見 [`api/auth-rest-client.md`](./api/auth-rest-client.md)。

---

## 4. Do / Don’t 速查

### Do

- 新 REST：加在 `API`／`BookingAPI`／`AdminAPI`，內部呼叫 `ApiClient._restRequest`
- Booking 新頁：只載 `booking-core-scripts.js`，不要複製 script 清單
- Firebase 好了確認 Console 有：`✓ AppAuth 已注入 Firebase Auth`
- 本機前後端 projectId／credentials 對齊後再測真登入

### Don’t

- 不要新增「第三套」fetch 包裝跟 `ApiClient` 搶入口
- 不要在 Booking HTML 重複貼 `config.js`／`api-client.js`／`booking-api.js`
- 不要在未收斂前直接刪除 `api-http.js` 或大幅改 `auth.js` 卻不測登入
- 不要提交 `.env`／`.env.local`／service account JSON／真實 token

---

## 5. 合併後建議煙霧測試（5～10 分鐘）

1. 啟動後端（依需要開 Firebase）+ `frontend` 的 `npm run dev`
2. 商城任一頁：Console 無致命錯誤；若有 Firebase config，應看到 AppAuth 注入 log
3. 預約頁（例如 `booking/pages/rental-guide.html`）：`window.AppConfig?.API_BASE_URL` 有值；`window.ApiClient` 存在
4. 登入一顆 provider（若本機有設 Firebase）：session 打到 `localhost:8080`，不是 Vite
5. 需登入的 API（例如會員／Checkout）：Request Header 有 `Authorization: Bearer ...`
6. 後台若 `useBackend: true`：確認有載 `api-client.js` 且 Admin 請求走 `ApiClient`

手動驗收文件：

- [`test/auth-rest-client-manual.md`](./test/auth-rest-client-manual.md)
- [`test/booking-backend-integration-manual.md`](./test/booking-backend-integration-manual.md)

---

## 6. 已知後續工作（不阻擋合併，但請排程）

| 項目 | 說明 |
|------|------|
| 收斂 `auth.js` | 改為使用 `AppAuth`／`ApiClient`，少依賴 `YuruiApiHttp` |
| 薄化或移除 `api-http.js` | 雙軌消失後，main 更好維護 |
| 文件／註解清理 | 標明「過渡」字樣可在收斂 PR 一併刪 |

若你正在改登入，請優先做收斂 PR，避免別人在過渡層上繼續疊功能。

---

## 7. 相關檔案速查

| 路徑 | 用途 |
|------|------|
| `frontend/storefront/js/api-client.js` | AppAuth + ApiClient（正式） |
| `frontend/storefront/js/firebase-app.js` | Firebase Web 初始化 |
| `frontend/storefront/js/api-http.js` | YuruiApiHttp（過渡） |
| `frontend/storefront/js/components/auth.js` | 登入 UI |
| `frontend/booking/js/booking-core-scripts.js` | Booking 共用腳本同步注入 |
| `frontend/booking/js/layout.js` | Booking layout + Firebase／AppAuth 注入 |
| `frontend/admin/js/admin-api.js` | Admin → ApiClient |
| `frontend/storefront/js/booking-api.js` | Booking → ApiClient |
| `backend/src/main/resources/application.properties` | `yuruicamp.firebase.project-id` 等 |
| `frontend/.env.example`、根目錄 `.env.example` | env 範本（勿提交真實密鑰） |

---

## 8. 給 Reviewer／Lead 的檢查清單

- [ ] PR 描述或合併說明有連到本文件  
- [ ] 沒有新增平行於 `ApiClient` 的正式 HTTP 層  
- [ ] Booking 新頁只使用 `booking-core-scripts.js`  
- [ ] 未提交 secret／本機 token  
- [ ] 若動到 auth／Firebase：煙霧測試第 5 節有跑過  

---

有疑問時：先看 [`api/auth-rest-client.md`](./api/auth-rest-client.md) 與 [`booking-shared-scripts.md`](./booking-shared-scripts.md)；再問開 PR 的人／Auth 負責人。
