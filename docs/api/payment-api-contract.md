# Payment API Contract（v0.2）

| 欄位 | 內容 |
|------|------|
| **狀態** | Partially Implemented（COD claim 消耗完成；ECPay 線 D 待實作） |
| **日期** | 2026-07-24 |
| **版本** | 0.2 |
| **共用** | [`common-api-conventions.md`](./common-api-conventions.md) |
| **DB** | `payment_method`／`payment_status` ENUM、`payment_notifications`、`orders`、`bookings` |
| **ENUM** | [`schema-enums.md`](../schema-enums.md) |

---

## 0. 一句話

線上付款**只走 ECPay**；**NotifyURL 是付款真相**；COD **僅商城**且履約後才 `paid`；預約**禁止 COD**。

---

## 1. `payment_method`（寫死）

| 值 | 用途 |
|----|------|
| `ecpay-credit` | 綠界信用卡 |
| `ecpay-atm` | 綠界 ATM |
| `ecpay-cvs` | 綠界超商 |
| `ecpay-other` | 其他綠界通道 |
| `cod` | 貨到付款（**僅 orders**；bookings CHECK 禁止） |

---

## 2. 端點

| 方法 | 路徑 | 認證 | 說明 |
|------|------|------|------|
| `POST` | `/api/checkout/sessions/{orderId}/ecpay` | 會員 | 商城：取得綠界表單欄位 |
| `POST` | `/api/booking/checkout/sessions/{bookingId}/ecpay` | 會員 | 預約：同上 |
| `POST` | `/api/payments/ecpay/notify` | **無** Bearer；驗簽 | 綠界背景通知（真相） |
| `GET`／`POST` | `/api/payments/ecpay/return` | 無／弱 | 導回前端成功／失敗頁（**不當**付款真相） |
| `POST` | `/api/checkout/sessions/{orderId}/confirm-cod` | 會員 | 商城 COD 確認（見 Checkout） |

---

## 3. `POST …/ecpay` 回應 — `EcpayLaunch`

| JSON | 型別 | 說明 |
|------|------|------|
| `orderId` 或 `bookingId` | string | 業務單號 |
| `merchantTradeNo` | string | 送綠界的商店訂單編號（需可對回 DB） |
| `actionUrl` | string | 綠界表單 POST URL（沙箱／正式） |
| `fields` | object | key→value，前端組 hidden form 提交 |
| `expiresAt` | string | 與結帳截止對齊 |

**不**在此回應宣告 `paymentStatus=paid`。

本機未接綠界時可用 stub：`actionUrl` 指測試頁或回傳固定 `fields`，並在文件標 `yuruicamp.ecpay.stub=true`。

---

## 4. Notify — `POST /api/payments/ecpay/notify`

### 4.1 行為（寫死）

1. 驗綠界簽章；失敗 → 非 200／依綠界要求回應  
2. 以 `merchantTradeNo`（等）對應 `orders` 或 `bookings`  
3. 寫入 `payment_notifications`（冪等）：  
   - 首次成功：`result=success` → 更新 `payment_status=paid`、`paid_at`  
   - 重複：`result=ignored_duplicate`，**不**改狀態兩次  
   - 失敗：`result=failed`  
4. 商城：相關 `product_stock_reservations` → `fulfilled`（規則在 Service）  
5. 商城有套券時呼叫 `CouponService.consumeAppliedClaim`；重複通知不得覆寫第一次 `consumed_at`
6. 回給綠界的 body／狀態碼依綠界文件（實作時鎖死一種）

目前尚未建立 ECPay Notify endpoint；上述步驟仍屬線 D 待實作，不得以未驗簽的測試通知直接消耗 claim。

### 4.2 `payment_notifications` 對照（內部，可不直接曝 API）

| DB | 說明 |
|----|------|
| `provider` | 固定 `ecpay` |
| `merchant_trade_no` | 商店訂單號 |
| `provider_trade_no` | 綠界交易號 |
| `order_id` XOR `booking_id` | 二擇一 |
| `raw_payload` | jsonb 原文 |
| `result` | `success` \| `ignored_duplicate` \| `failed` |

---

## 5. Return URL

- 只負責 **302／導頁** 到前端 success／failure  
- UI 應再呼叫 `GET /api/me/orders/{id}`（或 booking）確認 `paymentStatus`  
- **禁止**只靠 Return 參數把訂單標 paid

---

## 6. COD（僅商城）

| 步驟 | `payment_status` | 說明 |
|------|------------------|------|
| `confirm-cod` 後 | `unpaid` | 已成立訂單，未收款 |
| 後台履約完成（規則實作時定：出貨或 completed） | `paid` | Service 更新；`paid_at` |

若 COD 訂單有 `order_coupons` 快照，`confirm-cod` 成功時會在同一交易將 claim 改為 `consumed` 並設定 `consumed_at`。這代表優惠券已被本次成立的 COD 訂單占用，與貨款尚未收取是兩個不同狀態。

預約任何嘗試設 `cod` → 400／409（DB 亦有 `ck_bookings_no_cod`）。

---

## 7. v0.1 不做

| 項目 | 原因 |
|------|------|
| LINE Pay／舊 `credit-card` 字串 | ENUM 已移除 |
| 部分退款細 API | 後續；DB 有 `refund_status` 可先保留欄位 |
| 信用卡號經自家 API | 全部在綠界 |

---

## Changelog

| 版本 | 日期 | 說明 |
|------|------|------|
| 0.2 | 2026-07-24 | COD 成立時消耗 claim；鎖定未來 ECPay Notify 共用冪等消耗方法 |
| 0.1 | 2026-07-20 | ECPay 真相在 Notify；COD 僅商城 |
