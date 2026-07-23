# E-7 Booking 前端接線

## 用途

讓 Booking 前台在 `USE_MOCK_API=false` 時使用 E-1～E-6 的 Spring Boot API，不再把前端 JSON、價格、會員 ID 或付款狀態當成後端真相。

## 流程

```text
Booking 頁面
→ BookingAPI facade
→ ApiClient（Bearer + Envelope）
→ /api/booking/**
→ 顯示後端可用量、快照價格、bookingId 與 checkoutExpiresAt
```

## 規則

- `API_BASE_URL` 已包含 `/api`，facade 只寫 `/booking/...`，最終 URL 為 `/api/booking/...`。
- 公開營區、租借品、政策、公休與可用性不要求 Token；會員列表、詳情、Checkout、建立與取消要求 Firebase ID Token。
- Backend 模式不讀寫 `mockBookings`，也不傳 `customerId`、價格、快照、`status` 或 `paymentStatus`。
- 營區可用性固定呼叫 `POST /api/booking/check-availability`；租借數量由建立 Checkout 的後端交易最終確認。
- 列表解開 Envelope 的 `data` 並保留 `meta`；會員中心開啟明細時再讀完整 Booking 快照。
- 進入 `booking/pages/booking-cart.html` 後立即呼叫 `POST /api/booking/checkout/sessions`，在背包頁完成營位與租借庫存鎖定；數量變更時先取消舊 Session，再用新冪等鍵重新建立。
- `RENTAL_STOCK_INSUFFICIENT` 必須在背包頁顯示「商品剩餘數量不足請重新調整數量」，並阻止使用者進入結帳頁。
- 建立成功使用後端 `bookingId`、`pricing`、`paymentStatus=unpaid` 與 `checkoutExpiresAt`。
- `booking/pages/booking-checkout.html` 的「前往 ECPay」只讀取與目前背包 fingerprint 相符的暫存 Booking，再呼叫 `POST /api/booking/checkout/sessions/{bookingId}/ecpay`；不得再次呼叫建立 Session。
- 線 E 不收集信用卡、不產生 ECPay 表單，也不把 Booking 改成 paid／confirmed。

## 驗證結果

- `booking-api-facade.mjs`：路徑、認證、Envelope／meta、Backend 無 Mock 寫入與取消方法通過。
- `booking-checkout-request.mjs`：背包進頁建立 Session、精簡 Request、UUID 冪等鍵、庫存不足訊息、跨頁 fingerprint 與 ECPay 按鈕不重複建單通過。
- ApiClient、Checkout facade、Checkout Mock、Checkout Request 與 smoke 回歸全部通過。
- 本機 Spring Boot + Vite 實頁驗證通過：營區列表、營區詳情與待付款結果頁正常載入，沒有 console error。
- Puppeteer 瀏覽器 smoke 未執行完成，原因是本機沒有測試指定版本的 Chrome；沒有為此安裝新瀏覽器。
