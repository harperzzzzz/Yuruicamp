# 規格書：根絕對路徑與 API 契約（一步一驗）

| 欄位 | 內容 |
|------|------|
| **文件狀態** | Implemented（Steps 0–13） |
| **版本** | 1.0 |
| **日期** | 2026-07-18 |
| **目標** | 刪除路徑改寫；靜態資源用根絕對路徑；Mock 只走 API 門面；接 Spring 只改 config |

## 定案

- 靜態資源／腳本／CSS／導頁：一律網站根絕對路徑（Vite root = `frontend/`）
- `data-paths.js` 併入 `api-mock.js` 後刪檔
- 刪除：`resolveAppUrl` / `getAppBase` / `rewriteAssetUrlsDeep` / `rewriteAppPathsIn` / `data-app-path`
- 保留：`window.API`、`BookingAPI`、`AdminAPI`；`AppConfig.USE_MOCK_API` + `API_BASE_URL`

## 路徑鐵律

| 類型 | 允許 | 禁止 |
|------|------|------|
| 圖片欄位（JSON／API） | `/assets/...` 或 `https://...` | `../assets/...`、前端改寫 |
| HTML css/js/img/a | `/storefront/...`、`/assets/...`、`/booking/...`、`/components/...` | 為算深度而寫的跨站 `../` |
| Mock 資料檔 | 僅 API 層 `fetch('/data/...')` | 頁面直接 `../data/...` |

## Config

```js
USE_MOCK_API: true,
API_BASE_URL: 'http://localhost:8080/api',
ASSET_BASE_URL: '',
```

## REST 對照（方法名固定）

| 前端方法 | Mock | REST（建議） |
|----------|------|----------------|
| `API.products.getAll` | `/data/catalog/products.json`（正規化成契約） | `GET /api/products` → 見 [`docs/api/product-api-contract.md`](../docs/api/product-api-contract.md) |
| `API.products.getById` | 同上 filter | `GET /api/products/{id}` → 同上契約 |
| `API.orders.*` | orders.json + localStorage | `GET/POST /api/orders` |
| `API.coupons.getAll` | coupons.json | `GET /api/coupons` |
| `API.articles.getAll` | articles.json | `GET /api/articles` |
| `API.branches.getAll` | branches.json | `GET /api/branches` |
| `BookingAPI.*` | campgrounds / equipment / bookings | `GET /api/booking/...` |
| `AdminAPI.*` | MockDataPaths + configure | `/api/admin` |

## 基線（Step 0，2026-07-18）

- `npm run smoke` → passed (exit 0)
- `npm run validate:data` → OK (exit 0)
- `frontend/components/member-center.partial` → exists
- `frontend/components/shipping-address-modal.partial` → exists

## 一步一驗清單

見 Cursor plan「Path API Fix Checklist」Steps 0–13；每步驗收通過才進下一步。

## 接 Spring Boot

1. `USE_MOCK_API = false`
2. `API_BASE_URL` 指到 Spring
3. `AdminAPI.configure({ useBackend: true, baseUrl: '/api/admin' })`
4. 不必再改各頁 `/assets`、`/storefront` 路徑

真後端請求已統一經過 `frontend/storefront/js/api-client.js`：Firebase／開發 Token 由 `AppAuth.getIdToken()` 取得，Envelope 與錯誤由 `ApiClient._restRequest()` 處理。頁面不可自行新增後端 `fetch()`。

Checkout 已提供 `window.API.checkout` 六個契約方法。方法內只使用 `/checkout/sessions...`，因為 `API_BASE_URL` 已包含 `/api`。

`API.checkout` 會依 `USE_MOCK_API` 分流，但兩邊都回後端 Checkout 契約。Mock 使用 `mockCheckoutSessions`；Backend 模式禁止 `orders.create()` 寫入 Legacy `mockOrders`。

Checkout 頁面已改呼叫 `API.checkout.createSession()`。建立 Request 僅包含 `items[].variantId`、`quantity`、`shipping`、`paymentMethod` 與 `idempotencyKey`；會員由 Bearer principal 決定，商品快照與金額由後端重算。

商城 Checkout 的 `idempotencyKey` 由 `crypto.randomUUID()` 產生並保存在 sessionStorage。網路重試與連點沿用同一 key；成功保存 `orderId`，購物車變更、取消或逾時才清除狀態。

I-5 完成後，送出前金額只供預估；建立成功後摘要改用 `CheckoutSession.pricing`。Backend 模式不寫 Legacy Order、不消耗前端優惠券，且 ECPay 不在本站收集卡片資料。

I-6 由 Checkout 頁統一呈現 `draft`、`ready_to_pay`、Expired 與 Cancelled。Draft 使用 `API.checkout.updateSession()`，Ready 依 `checkoutExpiresAt` 倒數；取消與逾時清除 Session 但不清空購物車。
