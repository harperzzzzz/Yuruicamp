# ADM-W1-07 — 最低庫存閾值（min-stock）

| 欄位 | 內容 |
|------|------|
| **波次** | W1｜P0 |
| **狀態** | ✅ 完成（2026-07-23） |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W1-07 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | 無（表已存在） |
| **權限（定案）** | 讀 `products.view`／寫 `products.edit`（門檻屬商品營運；**不用** `movement.edit`） |

---

## 0. 開工前必讀

- [x] 表：`product_variant_min_stocks`、`rental_sku_variant_min_stocks`
- [x] **只改閾值，不改 on_hand**
- [x] 前端 `products.js` 有 min-stock 編輯模式可對接

**為什麼（一句）**：營運要設補貨警戒線，但不能用這支 API 直接改庫存數量。

---

## 1. 契約

- [x] 升版 Admin 契約：路徑寫死 `/api/admin/min-stocks` → **v0.12**（文件總版次其後已續升）
- [x] `inventoryDomain`: `store`｜`rental`
- [x] `GET`：依 domain／variant／location／productId 查詢
- [x] `PUT` bulk：設定 `minimumQuantity`（≥0）
- [x] **RBAC 寫死**：`products.view`／`products.edit`
- [x] 明確：本 API 不回寫庫存異動
- [x] 更新 [`docs/api/README.md`](../../../docs/api/README.md)

---

## 2. Schema

- [x] **不需改表**（現有 PK／欄位足夠）

---

## 3. 後端

- [x] Upsert 閾值（variant × location）
- [x] 驗證 variant／location 存在且 domain 相符
- [x] 讀取 API 供前端表格
- [x] RBAC＋OpenAPI（`Admin Min Stocks`）

---

## 4. 前端

- [x] min-stock 模式改打後端，不再只寫 local／JSON 思維
- [x] 成功後才更新 UI；與 G-2c 庫存唯讀並存（閾值可編、on-hand 仍唯讀）
- [x] readiness：`products.minStock=true`；products note 含最低庫存

---

## 5. 測試與驗收

- [x] 設定後 GET 一致（PostgreSQL IT）
- [x] 負數 → 400
- [x] 錯 domain 的 location → 400
- [x] 確認 `inventory_stocks.on_hand` 未變
- [x] 前端 facade／g6 readiness

---

## 6. 收尾

- [x] 總覽 ADM-W1-07 DoD 勾選
- [x] 本檔狀態 ✅
- [x] 若 W1 全完成：勾總覽「W1 完成門檻」

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
| 2026-07-23 | Agent | ✅ | 契約 v0.12；單元＋PostgreSQL IT＋facade／g6；RBAC `products.edit` |
