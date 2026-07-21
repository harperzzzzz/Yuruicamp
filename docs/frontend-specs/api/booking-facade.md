# Booking API Facade

## 用途

`window.BookingAPI` 是 Booking 頁面唯一的資料入口。Mock 模式讀取 `/data/**`；Backend 模式經 `ApiClient._restRequest()` 取得 Bearer Token、組合 Base URL、解開 Envelope 並轉換成現有頁面顯示模型。

## Backend 路徑

| 方法                       | HTTP 資源路徑                            | 認證 |
| -------------------------- | ---------------------------------------- | ---- |
| `getCampgrounds()`         | `/booking/campgrounds` + 各筆詳情        | 無   |
| `getCampgroundById(id)`    | `/booking/campgrounds/{id}`              | 無   |
| `getEquipment(id)`         | `/booking/equipment?campgroundId=`       | 無   |
| `getPolicy()`              | `/booking/policy`                        | 無   |
| `getClosures()`            | `/booking/closures`                      | 無   |
| `getAvailability(request)` | `/booking/check-availability`            | 無   |
| `createBooking(request)`   | `/booking/checkout/sessions`             | 必要 |
| `getCheckoutSession(id)`   | `/booking/checkout/sessions/{id}`        | 必要 |
| `getBookingsPage()`        | `/booking/bookings`                      | 必要 |
| `getBookingById(id)`       | `/booking/bookings/{id}`                 | 必要 |
| `cancelBooking(id)`        | `/booking/checkout/sessions/{id}/cancel` | 必要 |

`AppConfig.API_BASE_URL` 是 `http://localhost:8080/api`，因此 facade 不可再加 `/api`。`getBookingsPage()` 回 `{data, meta}`；相容既有會員中心的 `getBookings()` 回陣列，並在陣列的 `meta` 屬性保留分頁資訊。

## 建立 Request

只傳 `campgroundId`、日期、人數、zones、rentals、`couponClaimId=null`、非 COD 付款方式與冪等鍵。不得傳會員 ID、名稱／價格快照、總額、status 或 paymentStatus。

`bookingCheckoutIdempotencyKey` 與 `bookingCheckoutFingerprint` 存在 sessionStorage。相同內容重試沿用 UUID；內容變更才產生新 UUID。

## Payment 邊界

建立成功只代表 `pending + unpaid` 的 15 分鐘保留。成功頁顯示後端 `pricing.finalAmount` 與 `checkoutExpiresAt` 倒數，但不自行改變狀態。ECPay 表單、Notify 與 confirmed 屬線 D。
