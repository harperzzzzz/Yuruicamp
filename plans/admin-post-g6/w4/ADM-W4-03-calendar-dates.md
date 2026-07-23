# ADM-W4-03 — 假日曆 `calendar_dates`（K7）

| 欄位 | 內容 |
|------|------|
| **波次** | W4｜P2 |
| **狀態** | ⬜ 未開始 |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W4-03 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | 對齊線 H／架構 P2；與公休（G-4）互補 |
| **權限（建議）** | `booking-calendar.edit` |

---

## 0. 開工前必讀

- [ ] 公休 = 能不能訂；假日曆 = 哪天算假日價
- [ ] 表：`calendar_dates`

---

## 1. 契約

- [ ] Admin：`GET/PUT` 區間或 CRUD 寫死
- [ ] 欄位：date、is_holiday、holiday_name、source_version 等依 DB
- [ ] 說明 Booking 計價如何讀取

---

## 2. Schema

- [ ] 通常不需改

---

## 3. 後端

- [ ] 維護 API＋RBAC
- [ ] 確認 Checkout／availability 計價讀同一來源

---

## 4. 前端

- [ ] 假日曆維護 UI（booking-calendar）

---

## 5. 測試與驗收

- [ ] 標一日為假日 → 報價 holiday 天數／金額變化（至少一筆整合或手動）
- [ ] 與公休同時存在時行為符合文件

---

## 6. 收尾

- [ ] 總覽 W4-03；本檔 ✅

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
|  |  | ⬜／✅ |  |
