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
