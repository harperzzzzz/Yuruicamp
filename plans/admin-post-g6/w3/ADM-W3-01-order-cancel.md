# ADM-W3-01 — 訂單未出貨取消（O1）

| 欄位 | 內容 |
|------|------|
| **波次** | W3｜P1 |
| **狀態** | ⬜ Blocked by 線 D |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W3-01 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | **硬依賴** [`ADM-W3-00-payment-gate.md`](./ADM-W3-00-payment-gate.md)；G-2b；常接 W3-02 |
| **權限** | `orders.edit` |
| **不做** | O2 退貨（`returned`） |

---

## 0. 開工前必讀

- [ ] Gate ✅
- [ ] 僅 `unshipped` 可走本命令（契約寫死）
- [ ] 會員 Checkout cancel ≠ 本命令（本命令涵蓋已付款等客服場景）
- [ ] COD unpaid vs 線上 paid 取消規則分開寫

---

## 1. 契約

- [ ] `POST /api/admin/orders/{id}/cancel`（名稱可調，全文一致）
- [ ] 允許前置條件表（status／paymentStatus／refundStatus）
- [ ] Request 可選 `note`
- [ ] 成功後 status=`cancelled`；是否立刻進入退款見 W3-02（寫清：同交易呼叫或回 `refundRequired`）
- [ ] 冪等：已 cancelled 重送回放
- [ ] Admin 契約＋Payment 契約交叉引用

---

## 2. Schema

- [ ] 通常不需新欄位；沿用 `order_status`／history／reservations

---

## 3. 後端

- [ ] 悲觀鎖訂單
- [ ] 狀態機驗證 → update status＋history
- [ ] 釋放／回補 `product_stock_reservations`（對齊 Checkout 取消邏輯，但允許 paid）
- [ ] 觸發或標記退款（接 W3-02／Payment port）
- [ ] 優惠券規則依 Gate 定案處理
- [ ] RBAC＋OpenAPI

---

## 4. 前端

- [ ] Orders 詳情「取消」按鈕（僅允許狀態顯示）
- [ ] 確認對話框；成功刷新詳情／列表
- [ ] 錯誤 409 顯示原因

---

## 5. 測試與驗收

- [ ] 線上 paid + unshipped → cancel → cancelled＋庫存／保留正確
- [ ] 非法狀態（已 shipped）→ 409
- [ ] 重送冪等
- [ ] 無 edit → 403
- [ ] PostgreSQL 整合測試

---

## 6. 收尾

- [ ] 總覽 W3-01；本檔 ✅

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
|  |  | ⬜／✅ |  |
