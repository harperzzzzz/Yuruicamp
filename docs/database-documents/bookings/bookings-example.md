# 資料表實際互動
bookings
booking_selected_zones
booking_selected_rentals
booking_status_history


## 建立預約主檔
* bookings

id                         = B001
customer_id                = U022
campground_id              = C009
campground_name_snapshot   = 台中武陵溪流野營
region_snapshot            = 中部
check_in                   = 2026-03-31
check_out                  = 2026-04-02
guest_count                = 5
weekday_count              = 2
holiday_count              = 0
zone_total                 = 1900.00
rental_total               = 1800.00
applied_discount           = 0.00
final_amount               = 3700.00
status                     = cancelled
created_at                 = 2026-03-02 17:26:48+08
updated_at                 = 2026-03-07 17:26:48+08

---
代表：
會員 U022 預約台中武陵溪流野營。
住宿區間為 3 月 31 日入住、4 月 2 日退房，共 2 晚。
營位金額為 1,900 元、加租金額為 1,800 元，未折扣，最終金額為 3,700 元。
預約目前已取消。
---

## 選擇營位
* booking_selected_zones

id  booking_id  zone_id  zone_type_snapshot  price_weekday_snapshot  price_holiday_snapshot  quantity
1   B001        Z012     碎石區               950.00                  1200.00                 1

---
代表：
預約 B001 選擇 Z012 碎石區 1 個營位。
入住兩晚都是平日，因此營位小計為 `950 × 2 × 1 = 1900`。
---

## 加租裝備

* booking_selected_rentals
id                      = 1   
booking_id              = B001        
rental_listing_id       = R008               
rental_sku_variant_id   = v-P009-0              
sku_snapshot            = v-P009-0      
name_snapshot           = 折疊桌椅組      
specification_snapshot  = 鋁合金輕量版             
price_weekday_snapshot  = 450.00                  
price_holiday_snapshot  = 500.00                 
discount_snapshot       = 0.00               
quantity                = 2

---
代表：
預約 B001 加租「折疊桌椅組」2 組。
入住兩晚都是平日，因此裝備小計為 `450 × 2 晚 × 2 組 = 1800`。
---

## 記錄預約狀態歷程
* booking_status_history

id  booking_id  status     occurred_at                 actor_id  note
1   B001        pending    2026-03-02 17:26:48+08      NULL      預約單已送出
2   B001        confirmed  2026-03-02 17:26:48+08      A001      已付款
3   B001        cancelled  2026-03-07 17:26:48+08      A001      顧客臨時有事

---
代表：
預約先以 `pending` 建立；付款確認後變成 `confirmed`；後續由後臺使用者 A001 取消。
目前 bookings.status 應與最新一筆歷程的 `cancelled` 一致。
---

## 四張表組合後的完整資料
後端以 bookings 為主表，依 `booking_id` 查詢營位明細、裝備明細與歷程；將 snake_case 欄位轉為現有前端使用的 camelCase 巢狀 DTO。

```json
{
  "id": "B001",
  "customerId": "U022",
  "submittedAt": "2026-03-02 17:26:48",
  "status": "cancelled",
  "bookingInfo": {
    "campgroundId": "C009",
    "campgroundName": "台中武陵溪流野營",
    "region": "中部",
    "checkIn": "2026-03-31",
    "checkOut": "2026-04-02",
    "totalDays": 2,
    "weekdayCount": 2,
    "holidayCount": 0,
    "guestCount": 5
  },
  "selectedZones": [
    {
      "zoneId": "Z012",
      "zoneType": "碎石區",
      "quantity": 1,
      "subtotal": 1900
    }
  ],
  "selectedRentals": [
    {
      "listingId": "R008",
      "rentalSkuId": "R008",
      "variantId": "v-P009-0",
      "sku": "v-P009-0",
      "name": "折疊桌椅組",
      "specLabel": "鋁合金輕量版",
      "quantity": 2,
      "subtotal": 1800
    }
  ],
  "summary": {
    "zoneTotal": 1900,
    "rentalTotal": 1800,
    "appliedDiscount": 0,
    "finalAmount": 3700
  },
  "history": [
    { "time": "2026-03-02 17:26:48", "action": "預約單已送出" },
    { "time": "2026-03-02 17:26:48", "action": "已付款" },
    { "time": "2026-03-07 17:26:48", "action": "已取消（原因：顧客臨時有事）" }
  ]
}
```

---

欄位組合規則：
* `bookings.customer_id` → `customerId`
* `bookings.created_at` → `submittedAt`
* `check_out - check_in` → `bookingInfo.totalDays`
* `booking_selected_zones.zone_type_snapshot` → `selectedZones[].zoneType`
* 營位的 `subtotal` 由平／假日價格快照、住宿晚數與 quantity 計算。
* `booking_selected_rentals.rental_listing_id` → `selectedRentals[].listingId`
* `booking_selected_rentals.rental_sku_variant_id` → `selectedRentals[].variantId`
* `specification_snapshot` → `selectedRentals[].specLabel`
* 租借的 `subtotal` 由平／假日價格快照、折扣快照、住宿晚數與 quantity 計算。
* `booking_status_history.occurred_at` → `history[].time`；`status` 與 `note` 需由 API 格式化成目前前端的 `action` 文字。

## 實際前端資料流程
目前前端直接讀取 `data/commerce/camp-bookings.json` 的巢狀 DTO；結帳時由 `booking/js/booking-checkout.js` 組裝同樣結構，再透過 `js/booking-api.js` 寫入 `localStorage.mockBookings`。

後臺 `admin/js/bookings.js` 載入種子 JSON 後，會依 id 與 `mockBookings` overlay 合併，再呈現預約清單與明細。

因此，目前不會直接查詢四張 PostgreSQL 資料表。現行 Mock 使用 `rentalSkuId`、`equipmentId`、`productId` 等欄位，與目標資料表的 `rental_listing_id`、`rental_sku_variant_id` 不完全一致；正式 API 應輸出明確的 `listingId` 與 `variantId`。

正式 API 導入後，必須在同一交易中寫入 bookings、兩類明細與初始歷程，並在讀取時再組回此 DTO；`paymentStatus`、`equipmentReturned`、`contact`、`customerNote` 等現行前端欄位尚未對應到這四張表，需由其他資料表或 API DTO 補足。
