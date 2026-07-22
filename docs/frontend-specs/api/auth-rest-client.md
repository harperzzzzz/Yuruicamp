# 前端認證與 REST 共用層

> **協作者：** Firebase 合併後的影響範圍、Do/Don’t、單一 HTTP 主幹說明，見  
> [`../firebase-merge-into-main-notes.md`](../firebase-merge-into-main-notes.md)。  
> 過渡層 `YuruiApiHttp`／`api-http.js` 已移除；登入與 REST 一律走 `AppAuth`／`ApiClient`。

## 用途

`frontend/storefront/js/api-client.js` 是真後端請求的統一入口。頁面只呼叫 `window.API`、`BookingAPI` 或 `AdminAPI`，不自行取得 Token、解析 Envelope 或組合後端 URL。

## 流程

```text
頁面
→ API facade
→ ApiClient._restRequest()
→ AppAuth.getIdToken()
→ Spring Boot
→ 解開 { success, data, meta }
```

## 認證

- 正式模式：注入 Firebase Auth 後，從 `currentUser.getIdToken()` 取得 ID Token。
- 本機模式：只接受 development 環境的 `dev:` Token。
- 專案不會把 Amy 或其他固定會員 Token 寫在 Checkout／Booking 頁面。
- `auth: 'required'`：沒有 Token 就在送出請求前拋出 `AUTH_TOKEN_UNAVAILABLE`。
- `auth: 'optional'`：有 Token 就帶 Bearer，未登入仍可呼叫公開 API。
- `auth: 'none'`：登入 session 等不應帶 Bearer 的端點使用。

正式 Firebase 初始化完成後注入：

```javascript
window.AppAuth.configure({ auth: firebaseAuth });
```

本機臨時設定：

```javascript
window.AppAuth.configure({
  devToken: 'dev:uid-local:local@example.com:google:Local',
});
```

開發 Token 只保存在目前頁面的記憶體；也可在本機自行設定 `AppConfig.AUTH.DEV_TOKEN`，但不得提交真實 Token。

## REST 請求

```javascript
const profile = await window.ApiClient._restRequest('/me', {
  method: 'GET',
  auth: 'required',
});
```

共用層負責：

- 組合 `AppConfig.API_BASE_URL`。
- 加入 JSON Content-Type 與 Accept。
- 加入 Firebase／dev Bearer Token。
- 將物件 body 轉成 JSON。
- 解開成功 Envelope，預設只回傳 `data`。
- `includeMeta: true` 時回傳 `{ data, meta }`。
- 將後端錯誤轉成 `ApiRequestError`。

### FA-2：401／Token 過期

當 `auth` 不是 `'none'`，且回應為 **HTTP 401**（或 `UNAUTHORIZED`／`AUTH_TOKEN_UNAVAILABLE` 等）：

1. 若仍有 Firebase `currentUser`：**強制 `getIdToken(true)` 後自動重試一次**。
2. 重試仍失敗、或根本沒有可用 token：呼叫 `ApiClient.notifySessionExpired()`  
   - **商城／預約**：`YuruiAuth.logout` → toast「登入已過期」→ `openModal('loginModal')`  
   - **後台** `/admin/**`：`AdminAuth.logout` → 導向 `/admin/login.html`  
3. 並行請求有 debounce（約 2.5 秒），避免連續開多次登入框。
4. **不會**對 `auth: 'none'`（例如 session 登入端點）做踢人，以免登入失敗時誤清狀態。

頁面仍可自行處理 `ApiRequestError`（例如 Checkout 顯示錯誤面板）；共用層已負責清狀態與導回登入。

`ApiRequestError` 保留 `code`、`message`、`details` 與 `status`，頁面不可再從錯誤字串拆後端錯誤碼。

Mock JSON 與 HTML partial 是靜態資源，仍可由 API／layout 載入層使用 fetch；這不等於真後端 REST。頁面新增業務 API 時必須先加到對應 facade。
