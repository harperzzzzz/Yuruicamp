# ADM-W2-03 — 租借目錄寫入：SKU／規格（方案 C 前半）

| 欄位 | 內容 |
|------|------|
| **波次** | W2｜P1 |
| **狀態** | ⬜ 未開始 |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W2-03 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | 建議 [`ADM-W2-01`](./ADM-W2-01-categories.md)／[`ADM-W2-02`](./ADM-W2-02-brands.md)；參考 G-2c |
| **權限（建議）** | `products.view`／`products.edit`（或另立 rentals.* — 若另立需改 seed） |

---

## 0. 開工前必讀

- [ ] 定案方案 **C 前半**：`equipment_items` → `rental_skus` → `rental_sku_variants`
- [ ] **禁止**在本 API 寫 on-hand（庫存走 G-3 `inventoryDomain=rental`）
- [ ] 契約必須寫死路徑：獨立 `/api/admin/rentals` **或**掛在 products 下（擇一）
- [ ] listing／裝備規格標籤屬 [`ADM-W2-04`](./ADM-W2-04-rental-listings.md)

---

## 1. 契約

- [ ] 升版：列表／詳情／建立／更新／activate／deactivate（規格層）
- [ ] Request 不接受 `onHand`／`totalStock`／inventory 寫入欄位
- [ ] SKU 唯一、規格組合規則
- [ ] 與商城 products 共用 `equipment_items` 時的建立策略（新建 item vs 重用 itemId）寫死

---

## 2. Schema

- [ ] 通常不需改表；確認 FK 與 status ENUM

---

## 3. 後端

- [ ] 交易內建立／同步 sku＋variants（可參考 AdminProductService 模式）
- [ ] 未出現的舊 variant → inactive（不硬刪）
- [ ] RBAC＋OpenAPI
- [ ] lookups（若需要）

---

## 4. 前端

- [ ] 租借維護 UI 接 `AdminAPI`（取代 `updateRental` unsupported 的一部分）
- [ ] readiness：`products.rentalWrite` 可標 partial（等 W2-04 全開）
- [ ] 隱藏／禁用直接改庫存數字

> **⚠️ 相關延後**：完整「租借整頁定價／上架 UI」屬 W2-04，刻意不在舊 `products.js` 模型硬接。  
> 見 [`W2-ui-followups.md`](./W2-ui-followups.md)。

---

## 5. 測試與驗收

- [ ] 建立租借 SKU＋規格 → GET 可見
- [ ] 重複 SKU → 錯誤
- [ ] 帶 onHand 欄位 → 忽略或 400（與契約一致）
- [ ] 下架後公開 booking equipment 不可租（若公開讀已過濾 inactive）

---

## 6. 收尾

- [ ] 總覽 W2-03；本檔 ✅
- [ ] 可開工 W2-04

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
|  |  | ⬜／✅ |  |
