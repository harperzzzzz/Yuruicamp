# Booking API Contract（v0.1）

| 欄位 | 內容 |
|------|------|
| **狀態** | Locked（線 E 待實作） |
| **日期** | 2026-07-20 |
| **版本** | 0.1 |
| **共用** | [`common-api-conventions.md`](./common-api-conventions.md) |
| **相關** | [`payment-api-contract.md`](./payment-api-contract.md)、[`coupon-api-contract.md`](./coupon-api-contract.md) |
| **路徑前綴** | 統一 **`/api/booking/...`**（前端 `booking-api.js` 接線時從 `/booking/...` 改過來） |
| **策略** | D1.A：待付款 `bookings` + 占用／租借保留；**15 分鐘**；**禁止 COD** |

---

## 0. 一句話

公開讀營區／政策／可用性；進結帳才建 **pending + unpaid** 預約並鎖位／租借；金額後端重算；付款只走 ECPay。

---

## 1. 端點

### 1.1 公開讀

| 方法 | 路徑 | 認證 | 說明 |
|------|------|------|------|
| `GET` | `/api/booking/campgrounds` | 公開 | 可預約營區列表（`active=true`） |
| `GET` | `/api/booking/campgrounds/{id}` | 公開 | 營區詳情 + zones |
| `GET` | `/api/booking/equipment` | 公開 | 租借裝備；query `campgroundId` 必填 |
| `GET` | `/api/booking/policy` | 公開 | 預約政策 |
| `GET` | `/api/booking/closures` | 公開 | 公休／關閉 |
| `POST` | `/api/booking/check-availability` | 公開 | RPC：查可訂量（不鎖） |

### 1.2 會員寫／讀

| 方法 | 路徑 | 認證 | 說明 |
|------|------|------|------|
| `POST` | `/api/booking/checkout/sessions` | 會員 | 進結帳鎖位 |
| `GET` | `/api/booking/checkout/sessions/{bookingId}` | 會員 | 讀結帳中預約 |
| `PATCH` | `/api/booking/checkout/sessions/{bookingId}` | 會員 | 更新（如券） |
| `POST` | `/api/booking/checkout/sessions/{bookingId}/ecpay` | 會員 | 綠界表單 |
| `POST` | `/api/booking/checkout/sessions/{bookingId}/cancel` | 會員 | 取消釋放 |
| `GET` | `/api/booking/bookings` | 會員 | 我的預約列表 |
| `GET` | `/api/booking/bookings/{id}` | 會員 | 預約詳情 |

---

## 2. 公開資源（甲：對齊 DB）

### 2.1 `Campground`

| JSON | 型別 | DB |
|------|------|-----|
| `id` | string | `campgrounds.id` |
| `name` | string | `name` |
| `region` | string | `region` |
| `description` | string \| null | `description` |
| `active` | boolean | `active` |
| `zones` | array | 詳情必含；列表可省略或精簡 |

### 2.2 `Zone`（嵌在營區詳情）

| JSON | 型別 | DB |
|------|------|-----|
| `id` | string | `campground_zones.id` |
| `type` | string | `type` |
| `capacityPerSite` | integer | `capacity_per_site` |
| `priceWeekday` | string | `price_weekday` |
| `priceHoliday` | string | `price_holiday` |
| `totalSites` | integer | `total_sites` |
| `active` | boolean | `active` |

### 2.3 `RentalEquipment`（列表項，精簡）

| JSON | 型別 | 說明 |
|------|------|------|
| `id` | string | 對應 rental listing／SKU 業務 id（實作時對齊 schema 表名） |
| `campgroundId` | string | |
| `name` | string | 來自 equipment／rental 主檔 |
| `pricePerDayWeekday` | string | |
| `pricePerDayHoliday` | string | |
| `active` | boolean | |

> 租借表結構以 `rental_listings`／`rental_skus` 為準；實作時若欄位名微調，**先改本契約再改程式**。

### 2.4 `check-availability` Request／Response

**Request：**

| 欄位 | 型別 | 必填 |
|------|------|------|
| `campgroundId` | string | 是 |
| `checkIn` | string (`YYYY-MM-DD`) | 是 |
| `checkOut` | string (`YYYY-MM-DD`) | 是 |
| `zones` | array | 是 |
| `zones[].zoneId` | string | 是 |
| `zones[].quantity` | integer | 是（`> 0`） |

**Response `data`：**

| JSON | 型別 |
|------|------|
| `available` | boolean |
| `reasons` | string[] | 不可訂原因（可空） |
| `zones` | array | 各區 `zoneId`、`requested`、`availableQuantity` |

不寫保留帳（只讀）。可用性優先呼叫 DB 函式（如 `get_zone_availability`）或對等查詢。

---

## 3. 進結帳 — `POST /api/booking/checkout/sessions`

### 3.1 Request

| 欄位 | 型別 | 必填 |
|------|------|------|
| `campgroundId` | string | 是 |
| `checkIn` | string | 是 |
| `checkOut` | string | 是 |
| `guestCount` | integer | 是（`> 0`） |
| `zones` | array | 是（至少 1） |
| `zones[].zoneId` | string | 是 |
| `zones[].quantity` | integer | 是 |
| `rentals` | array | 否 |
| `rentals[].rentalSkuVariantId`（或契約實作鎖定的 id） | string | |
| `rentals[].quantity` | integer | |
| `couponClaimId` | number \| null | 否 |
| `paymentMethod` | string | 是（**不得** `cod`；建議 `ecpay-credit` 等） |
| `idempotencyKey` | string | 建議 |

忽略前端自算的 `finalAmount`。

### 3.2 Response — `BookingCheckoutSession`

| JSON | 型別 | DB／說明 |
|------|------|----------|
| `bookingId` | string | `bookings.id` |
| `status` | string | `pending`（進結帳） |
| `paymentStatus` | string | `unpaid` |
| `paymentMethod` | string | 非 `cod` |
| `checkoutExpiresAt` | string | +15m |
| `campgroundId` | string | |
| `campgroundName` | string | `campground_name_snapshot` |
| `region` | string | `region_snapshot` |
| `checkIn`／`checkOut` | string | date |
| `guestCount` | integer | |
| `weekdayCount`／`holidayCount` | integer | 後端依 `calendar_dates` 算 |
| `pricing` | object | 見下 |
| `zones` | array | 選位快照 |
| `rentals` | array | 可空 |
| `checkoutStep` | string | `draft` \| `ready_to_pay` |

#### `pricing`

| JSON | DB |
|------|-----|
| `zoneTotal` | `zone_total` |
| `rentalTotal` | `rental_total` |
| `discount` | `applied_discount` |
| `finalAmount` | `final_amount` |

字串金額；滿足 DB CHECK：`finalAmount = max(zoneTotal + rentalTotal - discount, 0)`。

---

## 4. 會員預約讀取 — `Booking`

對齊 `bookings` 表欄位（camelCase）+ `zones`／`rentals` 明細（來自 `booking_selected_zones`／`booking_selected_rentals`）。  
僅本人；列表可省略明細、詳情必含。

`booking_status`：`pending` \| `confirmed` \| `completed` \| `cancelled`。  
占用狀態以政策表為準（通常 `pending`／`confirmed`）。

---

## 5. 逾時

排程：`checkout_expires_at` 已過且仍 `unpaid` → `cancelled` + 釋放占用／租借保留（對齊商城 15 分）。

---

## 6. v0.1 不做

| 項目 | 原因 |
|------|------|
| COD | DB／產品禁止 |
| 舊 Mock 胖欄位（隨意 picsum 欄） | 不當契約真相 |
| 前端直接 `POST /booking/bookings` 當建單真相 | 改走 checkout sessions |

---

## Changelog

| 版本 | 日期 | 說明 |
|------|------|------|
| 0.1 | 2026-07-20 | 公開讀 + checkout；路徑統一 `/api/booking` |
