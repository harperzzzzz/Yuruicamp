# ADM-W3-03 — 預約已付款取消（B1）

| 欄位 | 內容 |
|------|------|
| **波次** | W3｜P1 |
| **狀態** | ⬜ Blocked by 線 D |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W3-03 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | **硬依賴** Gate；可參考 E-6 未付款取消釋放邏輯 |
| **權限** | `bookings.edit` |

---

## 0. 開工前必讀

- [ ] Gate ✅；預約 paid 真相可用
- [ ] 定案 **B1**：取消＋觸發退款（不是只改 status）
- [ ] Admin 不得把 unpaid 改成 paid
- [ ] 釋放：營位占用＋ `rental_stock_reservations`

---

## 1. 契約

- [ ] `POST /api/admin/bookings/{id}/cancel`（名稱寫死）
- [ ] 允許的 status／paymentStatus 組合（例如 paid+pending／paid+confirmed）
- [ ] 與退房 complete、會員未付款 cancel 的邊界
- [ ] 退款連動（Payment）
- [ ] 冪等

---

## 2. Schema

- [ ] 通常不需改

---

## 3. 後端

- [ ] 悲觀鎖 booking
- [ ] → cancelled＋history
- [ ] 釋放 zone／rental 保留（對齊 E-6，但允許 paid）
- [ ] 觸發退款
- [ ] RBAC＋OpenAPI

---

## 4. 前端

- [ ] Bookings 詳情取消操作＋確認
- [ ] 成功刷新；409 可讀

---

## 5. 測試與驗收

- [ ] paid pending／confirmed → cancel → 資源釋放
- [ ] 重送冪等
- [ ] 非法狀態 409
- [ ] 退款連動（stub）
- [ ] PostgreSQL 整合

---

## 6. 收尾

- [ ] 總覽 W3-03；本檔 ✅
- [ ] W3 三項＋Gate 皆完成 → 勾總覽 W3 波次門檻

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
|  |  | ⬜／✅ |  |
