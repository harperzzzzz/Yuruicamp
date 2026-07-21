# E-7 Booking 前端與 Swagger 驗證

## Swagger 準備

1. 在 `http://localhost:8080/swagger-ui.html` 呼叫 `POST /api/auth/firebase/session` 建立開發會員。
2. 按 `Authorize`，輸入相同 `dev:` Token。
3. 依 E-1～E-6 文件確認營區、可用性、建立 Checkout、本人列表與取消端點可用。

## 前端對照

1. 前端設定 `USE_MOCK_API=false`，並以 `AppAuth.configure({ devToken })` 注入同一 Token。
2. 從營區搜尋走到建立待付款預約。
3. 比對前端顯示的 `bookingId`、`pricing.finalAmount`、`paymentStatus` 與 Swagger `GET /api/booking/checkout/sessions/{bookingId}` 相同。
4. 在會員中心取消，再以 Swagger GET 確認狀態為 cancelled。

## 為什麼要驗證

Swagger 確認後端契約本身，前端對照則確認 facade 沒有重複 `/api`、遺失 Envelope／meta、寫入 Mock 或自行改付款狀態。兩邊結果一致才代表 E-7 接線完成。
