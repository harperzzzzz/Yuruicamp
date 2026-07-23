# ADM-W2-07 — 門市主檔 CRUD（K4）

| 欄位 | 內容 |
|------|------|
| **波次** | W2｜P1 |
| **狀態** | ⬜ 未開始 |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W2-07 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | 建議接在 [`ADM-W2-06`](./ADM-W2-06-inventory-locations.md) 之後 |
| **權限（建議）** | `products.edit` 或另訂；契約寫死 |

---

## 0. 開工前必讀

- [ ] 表：`branches`；公開 `GET /api/branches`（B-7）
- [ ] 訂單 `pickup_branch_id` FK：停用門市不得讓既有取貨單壞掉（禁硬刪）

---

## 1. 契約

- [ ] `/api/admin/branches` CRUD／啟停
- [ ] 公開讀只回 active（或既有行為對齊）
- [ ] 與庫位 `branch_id` 關聯說明

---

## 2. Schema

- [ ] 通常不需改

---

## 3. 後端

- [ ] Admin CRUD
- [ ] 公開 Branch API 與後台資料一致
- [ ] 停用／刪除安全檢查

---

## 4. 前端

- [ ] 門市維護 UI（若後台尚無頁，可先 Swagger／最小頁）

---

## 5. 測試與驗收

- [ ] CRUD；公開列表反映啟停
- [ ] 有訂單引用時禁硬刪

---

## 6. 收尾

- [ ] 總覽 W2-07；本檔 ✅

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
|  |  | ⬜／✅ |  |
