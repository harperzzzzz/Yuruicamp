# StorefrontCartPage 確認購物背包規格

**狀態：** 已實作  
**類別：** 頁面  
**來源：** `storefront/pages/cart.html`

## 概覽

商城商品詳情／共用購物車 Drawer 與正式 Checkout 之間的確認頁。頁面沿用 Storefront header、footer 與 `--yc-*` 設計 token，顯示商品規格、數量、預估金額及 Checkout Session 狀態。

## 流程責任

1. 進入頁面後，依目前 `AppState.cart` 建立只含 `items` 與 `idempotencyKey` 的 Draft Checkout。
2. 呼叫 `POST /api/checkout/sessions`，由後端重查商品可售狀態、計價並保留庫存 15 分鐘。
3. 建立成功後保存 `lastCheckoutSession`、`checkoutCompletedOrderId` 與購物車 fingerprint，才開放前往 `checkout.html`。
4. 商品數量或內容改變時，先取消舊 Session，再用新冪等鍵建立符合目前購物背包的 Session。
5. `STOCK_INSUFFICIENT` 顯示「商品剩餘數量不足請重新調整數量」，並用後端 `error.details[].reason` 顯示商品名稱與剩餘數量。
6. 結帳流程採圓形節點與連接線呈現；商品數量可透過加減按鈕或數字輸入框調整。

## 狀態

| 狀態        | 呈現                                     |
| ----------- | ---------------------------------------- |
| Loading     | 顯示正在確認庫存，停用前往結帳           |
| Ready       | 顯示庫存已暫時保留，開放前往填寫結帳資料 |
| Stock error | 顯示商品名稱與剩餘數量，保留數量調整控制 |
| Auth error  | 提醒登入；登入事件完成後自動重試         |
| Empty       | 顯示空背包與返回商品列表操作             |

## 驗收標準

- [ ] Header 與 footer 使用 Storefront 共用 partial。
- [ ] 建立 Request 不包含會員 ID、商品名稱、價格、總額或狀態。
- [ ] Session 建立前不可進入 `checkout.html`。
- [ ] 庫存不足明細不顯示內部 `variantId`。
- [ ] 數量變更會取消舊保留並重新建立 Session。
- [ ] 數字輸入框只接受 1 到系統上限之間的整數。
- [ ] 手機與桌面版皆可操作數量、移除商品及閱讀錯誤狀態。
