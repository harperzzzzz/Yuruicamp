# E-4 Booking 租借 Swagger 驗證

## 測試前確認

- PostgreSQL 已載入最新 schema 與 dev seed。
- 後端已啟動，開啟 `http://localhost:8080/swagger-ui.html`。
- Dev seed 的 `C002` 已有 `RL-DEV-C002-001`，variant 為 `RSV-DEV-001`，實體庫存為 6。

## Swagger 驗證流程

1. 先呼叫 `POST /api/auth/firebase/session`：

   ```json
   {
     "idToken": "dev:booking-e4-swagger:booking-e4-swagger@example.test:google:Booking Rental Tester"
   }
   ```

2. 按右上角 `Authorize`，貼上同一個 `dev:` token。
3. 展開 `POST /api/booking/checkout/sessions`。日期若已超出 Asia/Taipei 今天後 1～90 天窗口，請改用有效日期；`idempotencyKey` 每輪先換成未使用過的值。
4. 送出：

   ```json
   {
     "campgroundId": "C002",
     "checkIn": "2026-10-09",
     "checkOut": "2026-10-11",
     "guestCount": 2,
     "zones": [
       { "zoneId": "C002-Z-A", "quantity": 1 }
     ],
     "rentals": [
       {
         "rentalListingId": "RL-DEV-C002-001",
         "rentalSkuVariantId": "RSV-DEV-001",
         "quantity": 1
       }
     ],
     "couponClaimId": null,
     "paymentMethod": "ecpay-credit",
     "idempotencyKey": "booking-e4-swagger-001"
   }
   ```

5. 預期 HTTP 200，`rentals[0]` 含 SKU／名稱／規格／價格快照；上述日期包含 dev seed 的一個平日與一個假日，因此預期 `rentalTotal=400.00`、`finalAmount=3100.00`。
6. 使用新 key，將租借 quantity 改成 7，預期 HTTP 409、`RENTAL_STOCK_INSUFFICIENT`。
7. 使用新 key，把 `rentalListingId` 改成其他營區或把 variant 改成不相符值，預期 HTTP 404、`NOT_FOUND`。
8. 省略 rentals 或改成空陣列，預期仍可建立純營位 Booking。

## 完成標準

- 租借成功、庫存不足、listing 關係錯誤與無租借流程都符合 Booking Contract v0.6。
- 回應金額與快照皆來自後端資料庫，不接受前端自算值。

Swagger 驗證用來確認認證、dev seed、Request 與 Response 契約能人工串通；跨日重疊及兩筆交易搶最後庫存仍由 PostgreSQL 整合測試保障，因為 Swagger 無法可靠製造同時競爭。
