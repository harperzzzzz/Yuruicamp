# 訂單／預訂 Backend 畫面接線驗證

驗證日期：2026-07-22  
驗證範圍：Admin 訂單列表／詳情、Admin 預訂列表／詳情、會員本人訂單、會員本人預訂。

資料基準以 [`docs/seed/README.md`](../../seed/README.md) 的完整 Seed 為準；`frontend/data/**` 僅作為同源 JSON Mock 比對樣本。

## 結論

| 範圍                 | 真實後端 API                                        | API 與 JSON Mock                                  | 前端 Backend 模式                                                                         | 結果               |
| -------------------- | --------------------------------------------------- | ------------------------------------------------- | ----------------------------------------------------------------------------------------- | ------------------ |
| Admin 訂單列表／詳情 | 列表 222 筆；訂單 `221` 詳情與 1 筆明細可讀         | ID、會員、狀態、付款狀態、總額、明細數一致        | `AdminAPI` facade 契約測試通過，但正式頁未呼叫 `AdminAPI.configure({ useBackend: true })` | 部分通過           |
| Admin 預訂列表／詳情 | 列表 90 筆；預訂 `90` 詳情、1 個 zone、0 筆租借可讀 | ID、會員、狀態、付款狀態、總額、zone／租借數一致  | 同上，正式頁仍停在 Admin Mock 模式                                                        | 部分通過           |
| 會員本人預訂         | U001 列表 2 筆（`25`、`55`）；`55` 詳情可讀         | 兩筆 ID 與 Mock 一致；Booking facade 契約測試通過 | `USE_MOCK_API=false` 時會呼叫 `/api/booking/bookings`                                     | 通過（契約與資料） |
| 會員本人訂單         | `GET /api/me/orders` 回 HTTP 500                    | 無法與真實會員 API 比對                           | `API.orders.getAll/getByCustomerId` 不分流，Backend 模式仍讀 `orders.json`                | 未通過             |

目前不能宣稱四組畫面已全部完成 Backend 顯示驗收。Admin API 本身與 Seed／Mock 資料一致，但正式 Admin 頁沒有 Backend 啟用接點；會員訂單則同時缺少可用 API 與前端 REST 分流。

## 執行紀錄

### 真實 API

- Admin 驗證使用開發 Firebase session，將既有 `booking-seed@example.test` 管理員綁定至開發 UID `uid-admin-ui`。
- `GET /api/admin/orders?page=0&size=100&sort=placedAt,desc`：`meta.totalElements=222`。
- `GET /api/admin/orders/221`：成功，`items=1`、`history=1`。
- `GET /api/admin/bookings?page=0&size=100`：`meta.totalElements=90`。
- `GET /api/admin/bookings/90`：成功，`zones=1`、`rentals=0`。
- U001 `GET /api/booking/bookings?page=0&size=100`：`meta.totalElements=2`，ID 為 `55`、`25`。
- U001 `GET /api/booking/bookings/55`：成功，`zones=1`、`rentals=0`。
- U001 `GET /api/me/orders`：HTTP 500，Envelope 為 `INTERNAL_ERROR`。

### 前端契約測試

下列測試皆通過：

```text
node frontend/tests/admin-orders-bookings-facade.mjs
node frontend/tests/booking-api-facade.mjs
node frontend/tests/smoke.mjs
```

這些測試能確認 facade 的 URL、Envelope 解包與正規化契約，但不能取代正式頁實際啟用 Backend 模式的驗收。

### 瀏覽器限制

使用應用程式內瀏覽器嘗試開啟 `http://127.0.0.1:5173/admin/orders.html` 與 `http://localhost:5173/admin/orders.html` 時，瀏覽器均回報 `ERR_BLOCKED_BY_CLIENT`。因此本次沒有把瀏覽器畫面列為通過證據；待本機瀏覽器允許 localhost 後，仍需補做實際列表、詳情 modal 與會員中心畫面檢查。

## 待完成

1. 完成 `G-6`：在正式 Admin bootstrap 統一呼叫 `AdminAPI.configure({ useBackend: true })`，並提供有效的 Admin Bearer token。
2. 實作 `GET /api/me/orders` 與 `GET /api/me/orders/{orderId}`，限制只能查詢登入會員本人。
3. 將 `API.orders.getAll/getByCustomerId` 改為依 `USE_MOCK_API` 分流，Backend 模式不得讀取或合併 `orders.json`／localStorage。
4. localhost 可由瀏覽器開啟後，補跑 Admin 訂單／預訂與會員中心訂單／預訂的實際畫面驗收。
