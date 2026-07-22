# 線 F Coupon Swagger 驗證

## Swagger 驗證流程

1. 啟動 PostgreSQL 與 Spring Boot，開啟 `/swagger-ui.html`。
2. 呼叫 `GET /api/coupons`，確認只回傳有效且仍有名額的券。
3. 使用會員 Bearer Token 呼叫 `POST /api/me/coupons/claims`，Body 填入 `{ "couponId": 1 }`。
4. 呼叫 `GET /api/me/coupons`，記下回傳的 claim `id`。
5. 建立 Checkout，或以 `PATCH /api/checkout/sessions/{orderId}` 傳入 `couponClaimId`。
6. 確認回應的 `pricing.discount`、`pricing.total` 與 `couponClaimId` 都由後端結果決定。
7. 再次領取同一張券，確認回傳 `409 COUPON_ALREADY_CLAIMED`。
8. 對 Checkout 傳送空 JSON `{}`，確認優惠券被清除且折扣回到 `0.00`。

這項驗證可確認登入會員只能使用自己的 claim，名額不會被重複領取，前端金額也不能覆蓋後端折扣結果。付款後消耗仍需在線 D 完成後另外驗證。
