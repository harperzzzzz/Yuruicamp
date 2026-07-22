# 前端實際驗證總覽

| 欄位 | 內容 |
| --- | --- |
| 適用版本 | 目前 `frontend/` 多頁式 Vite 專案 |
| 驗證原則 | 自動測試先過，再做瀏覽器 Network／Storage／畫面驗證 |
| 正式 HTTP | `AppAuth` → `ApiClient` → `API`／`BookingAPI`／`AdminAPI` |
| 資料真相 | Backend 模式以 Spring Boot 回應為準；Mock 模式以 `frontend/data/**` 為準 |

## 文件入口

- [認證與會員驗證](./auth-member-validation.md)：Firebase／dev Token、Bearer、Envelope、會員隔離。
- [商城與預約驗證](./commerce-booking-validation.md)：Checkout、Coupon 邊界、Booking 與 Mock／Backend 分流。
- [後台驗證](./admin-validation.md)：Admin Session、RBAC、readiness 與各管理模組。
- 後端、Swagger 與資料庫驗證統一從 [`docs/backend-specs/test/README.md`](../../backend-specs/test/README.md) 進入。

## 1. 共用前置條件

1. 根目錄執行 `docker compose up -d`，`docker compose ps` 顯示 `yuruicamp-db` 為 `healthy`。
2. 在 `backend/` 設定與根目錄 `.env` 相同的 `DB_PASSWORD`，執行 `./mvnw.cmd spring-boot:run`。
3. 確認 `http://localhost:8080/api/health` 成功。
4. 在 `frontend/` 執行 `npm run dev`，以 `http://127.0.0.1:5173` 開啟頁面。
5. Backend 模式確認 `AppConfig.USE_MOCK_API === false`、`AppConfig.API_BASE_URL` 指向 Spring Boot。
6. DevTools Network 勾選 `Preserve log`、`Disable cache`，篩選 `Fetch/XHR`。

正式 Firebase 驗證必須改用 `frontend/.env.local` 與後端 Firebase service account；不得將 Token、service account 或 `.env.local` 提交到 Git。

## 2. 自動驗證 Gate

在 `frontend/` 執行：

```powershell
npm run lint
npm run stylelint
npm run validate:data
npm run smoke
npm run test:api-client
npm run test:checkout-facade
npm run test:checkout-mock
npm run test:checkout-request
npm run test:checkout-backend
npm run test:checkout-session-ui
npm run test:booking-facade
npm run test:booking-request
npm run test:admin-rbac
npm run test:admin-customers
npm run test:admin-orders-bookings
npm run test:admin-products
npm run test:admin-inventory
npm run test:admin-g4
npm run test:admin-g6
npm run build
```

判定規則：

- 任一指令非 `0`，整體 Gate 不通過；不得用其他測試成功抵銷。
- `npm run build` 顯示成功後，仍要確認部署目錄包含頁面實際引用的 JS、Admin、Booking、圖片與必要資料。只有 HTML／CSS 產出不算可部署。
- Vite 出現 `can't be bundled without type="module"` 時必須列為部署警告，不可只記錄 exit code。
- 自動測試只證明 facade、payload 與靜態規則；Firebase popup、頁面換頁、Storage、Network Header 與 UI 狀態仍需人工驗證。

## 3. 瀏覽器共用完成標準

- Console 無致命錯誤，Network 不出現重複 `/api/api`。
- 受保護請求含 `Authorization: Bearer ...`，但截圖與紀錄不得暴露完整 Token。
- 成功回應由 `ApiClient` 解開 Envelope；錯誤保留 HTTP status、`error.code` 與 `message`。
- Backend 模式不讀目標領域的 Mock JSON，也不寫入 `mockOrders`／`mockBookings` 偽造成交。
- Request 不傳會員 ID、前端價格或自行決定的付款／訂單狀態。
- 寫入必須後端成功後才更新畫面；4xx／5xx 時不得顯示假成功。

## 4. 目前不可宣稱通過的範圍

- COD 建單確認已可驗證；ECPay Gateway、Notify 與 Return 尚未實作，線上付款只能驗證待付款與導向介面。
- 會員訂單 `GET /api/me/orders` 與前端 `API.orders` Backend 分流已完成；網頁驗證依 [`member-orders-backend-validation.md`](./member-orders-backend-validation.md) 執行。
- Reviews、Admin tag pool、seller note、租借商品寫入沒有正式 Admin API，必須由 readiness 阻擋。
- 完整部署包、production API URL 與正式環境 secrets 另需部署驗證，不能用本機 Vite dev server 代替。

## 5. 最近一次實測基線（2026-07-22）

| Gate | 結果 |
| --- | --- |
| Checkout／Booking／Admin 15 組專屬 Node 測試 | 通過 |
| `npm run smoke`、`npm run stylelint` | 通過 |
| `npm run build` | exit code 0，但有大量傳統 script 無法 bundle 警告，且 `dist` 缺少完整 Admin／Booking／JS／data 部署內容 |
| `npm run lint` | 未通過：1 error、13 warnings |
| `npm run validate:data` | 未通過：文章 `art-001` 兩處引用未出現在公開商品資料的 `P010` |

因此目前不能標記前端 Release Gate 通過；修正後必須重新執行第 2 節全部指令。
# Checkout 線 D 前置驗證

- [`checkout-pre-payment-validation.md`](checkout-pre-payment-validation.md)：商城 Checkout 等待付款狀態頁、倒數、取消、逾時與非付款驗收。
