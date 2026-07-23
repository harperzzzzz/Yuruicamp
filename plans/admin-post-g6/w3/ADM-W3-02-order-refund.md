# ADM-W3-02 — 訂單退款狀態推進（O3）

| 欄位 | 內容 |
|------|------|
| **波次** | W3｜P1 |
| **狀態** | ⬜ Blocked by 線 D |
| **總覽** | [`../../admin-post-g6-task-list.md`](../../admin-post-g6-task-list.md) § ADM-W3-02 |
| **索引** | [`../README.md`](../README.md) |
| **Dependencies** | **硬依賴** Gate；常與 [`ADM-W3-01`](./ADM-W3-01-order-cancel.md) 同流程 |
| **權限** | `orders.edit`（或另立；契約寫死） |
| **不做** | O2 退貨；Admin **偽造**綠界退款成功 |

---

## 0. 開工前必讀

- [ ] `refund_status` ENUM：`none` → `requested` → … → `refunded`／`rejected`／`failed`
- [ ] 退款真相在 Payment／ECPay；Admin 只推進允許的命令並記錄 `order_event_history`
- [ ] 與取消的銜接方式已在契約寫死

---

## 1. 契約

- [ ] Admin 退款命令端點（例如 `POST .../refunds/request`、`.../approve` 等 — **按 Payment 定案精簡到本波需要的最少集合**）
- [ ] 非法轉換 → 409
- [ ] 成功後 `payment_status`／`refund_status` 最終值
- [ ] 與 [`payment-api-contract.md`](../../../docs/api/payment-api-contract.md) 交叉引用
- [ ] 文件註明：**O2 退貨不在本波**

---

## 2. Schema

- [ ] 沿用 `refund_status`、`order_event_history`；不足才加欄位

---

## 3. 後端

- [ ] 狀態機 Service
- [ ] 呼叫 Payment 退款埠（介面／adapter）；失敗寫 `failed`／可重試策略依契約
- [ ] 寫 `order_event_history`（非 status history）
- [ ] 取消流程整合（W3-01）

---

## 4. 前端

- [ ] 訂單詳情顯示 refundStatus
- [ ] 允許的退款操作按鈕；禁止任意下拉改狀態

---

## 5. 測試與驗收

- [ ] 合法推進路徑
- [ ] 非法跳狀態 409
- [ ] Payment stub 失敗時訂單狀態符合契約
- [ ] 事件歷程可查
- [ ] 與 O1 取消整合場景

---

## 6. 收尾

- [ ] 總覽 W3-02；本檔 ✅

---

## 驗收紀錄

| 日期 | 執行者 | 結果 | 備註 |
|------|--------|------|------|
|  |  | ⬜／✅ |  |
