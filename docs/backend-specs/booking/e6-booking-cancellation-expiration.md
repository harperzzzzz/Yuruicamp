# E-6 Booking 取消與逾時釋放

## 用途

讓會員安全取消尚未付款的 Booking Checkout，並由排程自動清除逾時 15 分鐘的待付款預約，恢復營位可用量及租借庫存。

## 流程

```text
主動取消或逾時候選
→ 鎖定 Booking
→ 重查 pending + unpaid
→ Booking 改為 cancelled
→ active 租借保留改為 released 並填 released_at
→ 新增 cancelled 狀態歷程
→ 同一交易提交
```

主動取消使用 `POST /api/booking/checkout/sessions/{bookingId}/cancel`，並以目前登入會員限制資料範圍。排程預設每 60 秒掃描一次 `checkout_expires_at <= now` 的候選 Booking。

## 規則

- 不存在與不屬於本人的 Booking 統一回 `404 NOT_FOUND`。
- 只有 `pending + unpaid` 可以轉為 cancelled；其他狀態回 `409 CONFLICT`。
- 已 cancelled 再取消會回放目前 Checkout，不重複釋放或新增歷程。
- 營位沒有獨立保留帳；Booking 離開政策占用狀態後，可用性查詢自然恢復。
- 付款通知與取消／排程必須鎖定同一筆 Booking，取得鎖後再判斷狀態。
- 可用 `YURUICAMP_BOOKING_EXPIRATION_ENABLED` 關閉排程，或用 `YURUICAMP_BOOKING_EXPIRATION_SCAN_MS` 調整掃描間隔。

## 驗證結果

- `BookingLifecycleIntegrationTest`：6 項全部通過。
- 覆蓋主動取消、本人限制、營位恢復、租借 released、未逾時／confirmed／cancelled 略過、排程重跑冪等，以及付款先取得鎖時不被取消。
- E-1～E-6 PostgreSQL 回歸：46 項全部通過，0 失敗、0 錯誤、0 略過。
