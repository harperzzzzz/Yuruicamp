# ADM-W4-01 — 營區主檔 CRUD（K5）

| 欄位 | 內容 |
|------|------|
| **波次** | W4｜P2 |
| **狀態** | ⬜ 未開始 |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W4-01 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | 無硬鎖；利於租借 listing 擴新營區 |
| **權限（建議）** | `booking-calendar.edit` 或 `bookings.edit`（契約寫死） |

---

## 0. 開工前必讀

- [ ] 表：`campgrounds`；關聯公休、listing、zones
- [ ] 禁硬刪若有 booking／listing 引用；改啟停

---

## 1. 契約

- [ ] `/api/admin/campgrounds` CRUD／啟停
- [ ] 與公開 `GET /api/booking/campgrounds` 對齊欄位策略甲

---

## 2. Schema

- [ ] 通常不需改

---

## 3. 後端

- [ ] CRUD＋引用檢查＋RBAC＋OpenAPI
- [ ] 公開讀只反映 active（依契約）

---

## 4. 前端

- [ ] 營區維護 UI（可掛 booking-calendar 區）

---

## 5. 測試與驗收

- [ ] CRUD；公開列表一致；有引用禁刪

---

## 6. 收尾

- [ ] 總覽 W4-01；本檔 ✅ → 可開工 W4-02

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
|  |  | ⬜／✅ |  |
