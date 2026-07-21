# E-6 Booking 取消 Swagger 驗證

## 前置條件

- 後端與 PostgreSQL 已啟動，Swagger 位於 `http://localhost:8080/swagger-ui.html`。
- 使用 `POST /api/auth/firebase/session` 建立開發會員，並在 Swagger 的 `Authorize` 輸入同一個 `dev:` Token。
- 先用 `POST /api/booking/checkout/sessions` 建立一筆 `pending + unpaid` 預約，記下回傳的 `bookingId`。

## 主動取消

1. 展開 `POST /api/booking/checkout/sessions/{bookingId}/cancel`，填入剛建立的 `bookingId` 後送出。
2. 預期 HTTP 200，`status=cancelled`、`paymentStatus=unpaid`、`checkoutStep=closed`。
3. 再送一次相同取消請求，預期仍為 HTTP 200，內容維持 cancelled。
4. 呼叫 `POST /api/booking/check-availability` 查詢相同日期與營位，確認取消後數量已恢復。
5. 改用另一個會員 Token 取消該 Booking，預期 HTTP 404、`NOT_FOUND`。

## 逾時排程

Swagger 不提供修改 `checkout_expires_at` 或直接觸發排程的管理端點。完整的逾時、租借釋放、重跑冪等及付款競爭，應以 `BookingLifecycleIntegrationTest` 驗證；不要為了人工測試新增可改狀態的公開 API。

若在可丟棄的本機資料庫做人工驗證，可先建立 Booking，再把該筆 `checkout_expires_at` 調整為過去時間，等待預設最多約 60 秒，最後用 `GET /api/booking/checkout/sessions/{bookingId}` 確認已 cancelled。正式或共用環境不可直接修改資料庫。

## 為什麼要驗證

這組流程確認重送取消不會重複寫入，且逾時資料能釋放營位與租借庫存；付款與取消的最終結果仍由資料庫鎖後狀態決定。
