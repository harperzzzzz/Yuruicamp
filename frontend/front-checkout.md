# Storefront 商城結帳流程

## 1. 畫面行為

- `checkout.html` 在購物車有商品時可瀏覽與填表；送出前必須登入。
- 姓名、手機與 `Email` 初始保持空白，只有按下 `#fillProfileBtn` 才帶入會員資料。
- `#checkoutPricingSource` 與 `#checkoutActionStatus` 已移除；訂單編號改顯示在 Checkout 狀態面板。
- 宅配顯示地址編輯器；門市取貨顯示 `#checkoutPickupBranch`，資料由 `API.branches.getAll()` 取得。無門市或載入失敗時停用門市取貨。
- `#confirmOrderBtn` 初始為「確認結帳」；ECPay 建立 Ready Session 後顯示「前往 ECPay」，COD 則在同一次操作中自動確認成立。

## 2. 建立 Checkout

前端只送商品識別、數量、配送、付款、優惠券與冪等鍵。會員身分、價格與商品快照由後端決定。

宅配的 `shipping`：

```json
{
  "method": "delivery",
  "recipientName": "王小明",
  "phone": "0912345678",
  "address": "臺北市信義區信義路一段 1 號",
  "pickupBranchId": null
}
```

門市取貨的 `shipping`：

```json
{
  "method": "pickup",
  "recipientName": "王小明",
  "phone": "0912345678",
  "address": null,
  "pickupBranchId": "branch-001"
}
```

後端會依 `pickupBranchId` 查詢門市並保存地址快照，不信任前端提供的門市地址。

## 3. Session 狀態

```text
POST /api/checkout/sessions
├─ draft：PATCH /api/checkout/sessions/{orderId} 補齊資料
└─ ready_to_pay：啟動 15 分鐘庫存保留倒數
```

- 商品明細不可用 `PATCH` 修改；要改數量或移除商品時，先取消再建立新的 Checkout。
- `sessionStorage.lastCheckoutSession` 保存完整回應。
- `sessionStorage.checkoutCompletedOrderId` 保存目前訂單編號。
- `sessionStorage.checkoutIdempotencyKey` 保存同一次建單的冪等鍵。

## 4. 貨到付款

```text
POST /api/checkout/sessions
→ ready_to_pay
→ POST /api/checkout/sessions/{orderId}/confirm-cod
→ completed
→ checkout-success.html
```

使用者只按一次「確認結帳」。前端收到 `paymentMethod=cod` 且 `checkoutStep=ready_to_pay` 後，立即呼叫 `confirm-cod`，不顯示第二個確認步驟。

確認後 `paymentStatus` 仍為 `unpaid`，因為實際付款發生在收貨時；`checkoutExpiresAt` 與庫存保留期限改為 `null`，訂單不再受 `15` 分鐘 Checkout 倒數限制。

後端確認成功後，前端才清空共用購物車與本次 Checkout 暫存，並以 query string 的 `orderId` 導向狀態頁。建立失敗、取消或仍在付款中的 Session 不得清空購物車。

## 5. ECPay

前端呼叫 `POST /api/checkout/sessions/{orderId}/ecpay`，只把後端簽好的 `actionUrl` 與 `fields` 組成 `POST form` 送往 ECPay。前端不保存密鑰、不產生 `CheckMacValue`，也不把瀏覽器返回頁當成付款成功證明。

目前 repository 缺少 `.ecpay-skill/SKILL.md` 與後端 ECPay 端點實作，因此實際導轉仍會收到後端未實作錯誤；付款成功只能在後端完成 Notify 驗證後成立。

## 6. 取消、逾時與缺貨

- `POST /api/checkout/sessions/{orderId}/cancel` 取消未付款訂單並釋放 active 保留帳，購物車保留。
- 未確認的 Ready Session 到期後由排程取消並釋放庫存。
- `STOCK_INSUFFICIENT` 回應的 `details` 至少包含 `variantId`、`requested` 與 `available`；前端以安全文字顯示，引導使用者調整購物車後重新建立 Checkout。

## 7. 資料庫欄位

`orders.shipping_method` 使用既有 PostgreSQL `shipping_method` ENUM；`orders.pickup_branch_id` 外鍵指向 `branches.id`。宅配必須沒有門市 ID，門市取貨必須有有效門市 ID。
