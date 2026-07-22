# 商城 Checkout 與 Booking 實際驗證

## 1. 自動驗證

在 `frontend/` 執行：

```powershell
npm run test:checkout-facade
npm run test:checkout-mock
npm run test:checkout-request
npm run test:checkout-backend
npm run test:checkout-session-ui
npm run test:booking-facade
npm run test:booking-request
```

所有指令必須為 exit code `0`。這組測試驗證 URL、Bearer 選項、Request 白名單、冪等鍵、Mock adapter、Session Storage 與錯誤狀態；不取代真 HTTP 驗證。

## 2. 商城 Checkout Backend 流程

前置資料：購物車至少有一個資料庫存在、active 且有可售量的 `variantId`。剛重建資料庫時先清空舊購物車再重新加入商品。

1. 開啟 `/storefront/pages/checkout.html` 並完成登入。
2. 確認買家資訊、物流選擇與付款方式三個面板進入畫面時預設全部展開，且各標題按鈕仍可個別收合／展開。
3. 確認送出前金額標示為預估；頁面沒有卡號、有效期或 CVV 欄位。
4. 送出後 Network 應呼叫 `POST /api/checkout/sessions`。
5. Request 只包含 `items[].variantId`、`quantity`、`shipping`、`paymentMethod`、`couponClaimId`（適用時）與 `idempotencyKey`。
6. Request 不得包含 `customerId`、商品名稱、單價、總額、狀態或付款狀態。
7. 畫面金額必須改用回應的 `pricing`；`sessionStorage.lastCheckoutSession` 保存完整 Session。
8. 重整後不得再建立新訂單；相同 payload 與冪等鍵回放同一 `orderId`，不同 payload 預期 `409 IDEMPOTENCY_CONFLICT`。
9. Draft 修改呼叫 `PATCH /api/checkout/sessions/{orderId}`；取消呼叫 `POST .../{orderId}/cancel`。
10. Backend 模式不得新增 `mockOrders` 或 Legacy Order。

狀態預期：

| 情境 | 預期 |
| --- | --- |
| 待付款 | `ready_to_pay`，依 `checkoutExpiresAt` 倒數 |
| 主動取消 | `cancelled`／closed，購物車不因取消被清空 |
| 逾時 | `expired` 或後端取消結果，清除 Session 暫存 |
| ECPay | 只顯示下一步提示；目前不可驗證實際付款 |
| COD | Payment 線完成前不可宣稱端到端通過 |

## 3. Coupon 邊界

商城可用自己的 `couponClaimId` 更新 Checkout，折扣只採後端 `pricing.discount`。切換或清除後重新比對後端金額。Booking Coupon 關聯尚未完成，Booking 傳非 null claim 應被拒絕，不能由前端自行折價。

## 4. Booking Backend 流程

使用 Seed 中存在的營區、zone 與租借 listing；ID 必須以實際 API 回應為準，不可照抄過期範例。

1. `/booking/pages/camp-search.html` 應呼叫：
   - `GET /api/booking/campgrounds`
   - `GET /api/booking/policy`
   - 查日期時 `POST /api/booking/check-availability`
2. 不應下載 `campgrounds.json`、`camp-bookings.json` 或 `booking-policy.json`。
3. 營區詳情呼叫 `GET /api/booking/campgrounds/{id}` 與 `GET /api/booking/equipment?campgroundId=...`。
4. 進入 Checkout 後建立 `POST /api/booking/checkout/sessions`，Request 只送營區／zone／租借 ID、數量、日期、人數、付款方式與冪等鍵。
5. 回應必須是 `pending + unpaid`，金額、快照、`bookingId` 與 15 分鐘期限由後端決定。
6. 成功頁不得顯示已付款或 confirmed；Payment 線尚未完成。
7. 會員中心呼叫 `GET /api/booking/bookings` 與詳情 API，只顯示本人資料。
8. 取消呼叫 `POST /api/booking/checkout/sessions/{bookingId}/cancel`，重送仍保持 cancelled。
9. 比較前後 `localStorage.mockBookings`，Backend 流程不得修改；`bookingCart` 只允許作為送出前暫存。

遇到建單失敗，先記錄 Request URL、HTTP status、`error.code`、`message`、是否剛重建 DB、是否已重新登入。`400`／`404`／`409`、`STOCK_*`、`ZONE_*`、`VARIANT_*` 通常是業務或 Seed，不要先改 Firebase。

## 5. Mock 模式

將 `USE_MOCK_API` 設為 `true` 後：

- Checkout 與 Booking 應只讀 `/data/**` 與對應 Mock Storage。
- Mock adapter 回傳形狀仍須符合後端契約。
- Mock 與 Backend 測試資料彼此隔離，切換模式前清楚記錄 Storage 基線。
- Mock 成功不能作為 PostgreSQL 庫存、會員隔離或交易鎖驗收證據。

## 6. 通過標準

- 自動測試全綠，Network 路徑、Header 與 payload 正確。
- ID、金額、狀態、逾時與取消皆以後端回應為準。
- 冪等重送不重複建立或扣庫存。
- Backend 模式不讀／寫成交 Mock。
- 已知未完成的 Payment、Booking Coupon 與會員訂單明確標記為未通過。
