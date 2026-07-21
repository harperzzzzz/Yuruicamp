# E-3 Booking Checkout Swagger 驗證

## 測試前確認

- PostgreSQL 已載入最新 schema 與 dev seed。
- 後端已啟動，開啟 `http://localhost:8080/swagger-ui.html`。
- 日期必須落在 Asia/Taipei 今天後 1～90 天內，且最多 7 晚。

## Swagger 驗證流程

1. 先展開 `POST /api/auth/firebase/session`，送出：

   ```json
   {
     "idToken": "dev:booking-e3-swagger:booking-e3-swagger@example.test:google:Booking Tester"
   }
   ```

2. 按 Swagger 右上角 `Authorize`，貼上同一個 `dev:` token。
3. 展開 `POST /api/booking/checkout/sessions`，按 `Try it out`，送出下列內容。日期若已超出窗口，請改成有效日期：

   `idempotencyKey` 的尾碼每次人工驗證先換成未使用過的值；只有第 5 步回放時才重複使用。

   ```json
   {
     "campgroundId": "C002",
     "checkIn": "2026-10-09",
     "checkOut": "2026-10-11",
     "guestCount": 2,
     "zones": [
       { "zoneId": "C002-Z-A", "quantity": 1 }
     ],
     "rentals": [],
     "couponClaimId": null,
     "paymentMethod": "ecpay-credit",
     "idempotencyKey": "booking-e3-swagger-001"
   }
   ```

4. 預期 HTTP 200，並確認：

   - `status=pending`
   - `paymentStatus=unpaid`
   - `checkoutStep=ready_to_pay`
   - `checkoutExpiresAt` 約為建立後 15 分鐘
   - 金額、平假日晚數與 zones 快照由後端回傳

5. 原內容與相同 `idempotencyKey` 再送一次，預期回傳相同 `bookingId`。
6. 保留相同 key，但把 `guestCount` 或 quantity 改掉，預期 HTTP 409、`IDEMPOTENCY_CONFLICT`。
7. 把 `paymentMethod` 改成 `cod`，並使用新 key，預期 HTTP 400、`VALIDATION_ERROR`。

## 完成標準

- 建立、冪等回放、payload 衝突與 COD 拒絕都符合目前的 Booking Contract v0.6。
- 回應價格不是由前端提供，並且預約保持待付款狀態。

Swagger 驗證用來確認認證、Request JSON、Envelope 與開發 seed 可以人工串通；多執行緒鎖位與防超賣仍由 PostgreSQL 整合測試保障，因為 Swagger 無法可靠地同時送出競爭交易。
