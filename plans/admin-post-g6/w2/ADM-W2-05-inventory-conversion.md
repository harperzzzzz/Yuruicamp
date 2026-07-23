# ADM-W2-05 — 跨領域庫存轉換（商店 ↔ 租借）

| 欄位 | 內容 |
|------|------|
| **波次** | W2｜P1 |
| **狀態** | ⬜ 未開始 |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W2-05 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | **G-3**；建議 [`ADM-W2-03`](./ADM-W2-03-rental-skus.md)、[`ADM-W2-06`](./ADM-W2-06-inventory-locations.md) |
| **權限** | `movement.edit`（讀 `movement.view`） |

---

## 0. 開工前必讀

- [ ] 讀 `docs/database-documents/inventory/inventory-conversions.md`
- [ ] 定案：**完整成對** `conversion_out`＋`conversion_in`＋`inventory_conversions`＋冪等
- [ ] draft 明細仍維持「只能加、不能改刪」（總覽定案）
- [ ] 不可負庫、不可低於 active 保留；失敗整筆 rollback

---

## 1. 契約

- [ ] 升版 Admin／Inventory 契約：轉換專用端點或擴充 movement type
- [ ] 建立 draft（兩端 location、source store variant、dest rental variant、quantity、idempotencyKey）
- [ ] 過帳 API；重送冪等
- [ ] 錯誤碼：庫存不足 `409`、domain 不符、variant 不存在
- [ ] 明確：單邊假轉換不允許

---

## 2. Schema

- [ ] 表已存在則不改；確認 `inventory_conversions` 欄位與 FK
- [ ] movement_type 是否已含 `conversion_out`／`conversion_in`（否則 ENUM／CHECK 變更）

---

## 3. 後端

- [ ] 同交易建立兩邊異動表頭／明細＋ conversions 列
- [ ] post：固定順序鎖庫存 → 扣 store → 加 rental → 兩邊標 posted
- [ ] cancel draft：兩邊一併作廢
- [ ] 冪等鍵防重
- [ ] 併發測試案例設計

---

## 4. 前端

- [ ] 轉換／調撥 UI 改打真 API（勿只產前端假異動）
- [ ] 成功後刷新庫存唯讀摘要
- [ ] 錯誤訊息可讀

> **⚠️ 刻意延後（後端可用）**  
> 舊版商品頁「**調撥到租借**」Modal（`submitTransferToRental` 等）仍只改**前端記憶體 cache**，**不會**呼叫 `/api/admin/inventory-conversions`，也不會寫成對 `conversion_out`／`conversion_in`。  
> 詳見專檔：[`W2-ui-followups.md`](./W2-ui-followups.md) § 延後項 B。  
> 驗收本項後端請用 Swagger／`AdminAPI.inventoryConversions.*`，不要只靠商品頁調撥按鈕。

---

## 5. 測試與驗收（必要）

- [ ] PostgreSQL 整合：成功轉換後兩邊 on_hand 正確
- [ ] 庫存不足 → 全 rollback
- [ ] 重複 idempotencyKey → 回放不雙重扣加
- [ ] 併發兩筆搶最後數量 → 僅一筆成功

---

## 6. 收尾

- [ ] 總覽 W2-05；本檔 ✅
- [ ] 若 W2 其他項也完成：勾 W2 波次門檻

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
|  |  | ⬜／✅ |  |
