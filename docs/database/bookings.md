# bookings
# booking_selected_rentals
# customers
# booking_history

## OneToMany
customer 1 : bookings N
bookings 1 : booking_selected_rentals N
bookings 1 : booking_history N

## problems :
1. bookings.zone_total、rental_total、applied_discount、final_amount 與明細金額存在彙總冗餘。
2. booking_selected_rentals.subtotal 是可由數量與價格資料推導的金額。
3. bookings.campground_name、region 與 campground_id 對應資料重複。
4. booking_selected_rentals 同時保存租借/商品/變體 FK 與 sku、name、spec_label。
---

1. customers
id 
avater
name
phone
email
birthday
registered_at
total_spent 累積消費金額，可用於會員分級或後台分析
tier
tier_name
points
first_purchase_used 是否已使用首購優惠
preferences
shipping_address
tags
auth_provider ，OAuth 登入來源
created_at
updated_at



2. bookings
id
customer_id
submitted_at 預約送出時間
payment_status
status
equipment_returned 租借裝備是否已歸還
campground_id
  FK，指向 campgrounds.id，用於關聯目前營區主檔。
campground_name_snapshot
  預約成立當下的營區名稱快照。由後端根據 campground_id 查 campgrounds.name 後寫入。
  不接受前端任意傳入。
campground_region_snapshot
  預約成立當下的地區快照。由後端根據 campground_id 查 campgrounds.region 後寫入。
  不接受前端任意傳入。
check_in
check_out
`total_days 總晚數／天數統計，用於金額與顯示，可以用check_in, check_out 計算，在前端計算一次用於顯示，後端重新計算一次防止竄改`
    `保險加上CHECK (check_out > check_in)`
weekday_count 給「營位價格計算」和「事後查核」用，只知道天數不會知道假日平日總數
holiday_count 給「營位價格計算」和「事後查核」用
guest_count 入住人數
zone_total 營位小計
rental_total 租借裝備小計
applied_discount 已套用折扣金額
final_amount
customer_note
seller_note 後台／客服備註

## zone_total、rental_total、applied_discount、final_amount 改動 :
* bookings 只移除 total_days，保留 weekday_count / holiday_count
- total_days = check_out - check_in 是純日期差，最適合推導。
- DB 可改成不存 total_days，前後端顯示時即時計算。

* 保留 bookings.zone_total、rental_total、applied_discount、final_amount，但明確定義它們是「成交當下金額快照」。新增規則：
    - 單一 service / transaction 更新彙總 :
    (正式後端則應該放在 service layer)
    ---
    function recalcBookingSummary(booking) {
    const zoneTotal = (booking.selectedZones || [])
        .reduce((sum, item) => sum + Number(item.subtotal || 0), 0);

    const rentalTotal = (booking.selectedRentals || [])
        .reduce((sum, item) => sum + Number(item.subtotal || 0), 0);

    const appliedDiscount = Number(booking.summary?.appliedDiscount || 0);

    booking.summary = {
        zoneTotal,
        rentalTotal,
        appliedDiscount,
        finalAmount: zoneTotal + rentalTotal - appliedDiscount,
    };

    return booking;
    }
    ---
    - 有會動到明細或折扣的流程都必須走 :
    (正式後端則應該放在 service layer)
    ---
    function updateBookingItems(booking, nextZones, nextRentals, nextDiscount) {
    booking.selectedZones = nextZones;
    booking.selectedRentals = nextRentals;

    booking.summary = {
        ...(booking.summary || {}),
        appliedDiscount: nextDiscount || 0,
    };

    return recalcBookingSummary(booking);
    }
    ---

    - 禁止直接改明細而不重算 summary
    前端 mock JSON 階段，可以約定：
    booking.selectedZones
    booking.selectedRentals
    booking.summary
    只能透過 helper 更新。

    - 加 validation
    ---
    CHECK (zone_total >= 0),
    CHECK (rental_total >= 0),
    CHECK (applied_discount >= 0),
    CHECK (final_amount >= 0),
    CHECK (final_amount = zone_total + rental_total - applied_discount)
    ---

    - 稽核測試 / 資料檢查 script
    用來掃既有資料，找出已經不一致的 booking。
    smoke/data consistency tes 添加:
    對每一筆 booking：
        expectedZoneTotal = selectedZones subtotal sum
        expectedRentalTotal = selectedRentals subtotal sum
        expectedFinalAmount = expectedZoneTotal + expectedRentalTotal - appliedDiscount
    如果和 summary 不一樣，列出 booking id 和差異

## campground_name、region 與 campground_id 改動:
更改語意campground_name_snapshot, campground_region_snapshot
---
CREATE TABLE bookings (
  id BIGSERIAL PRIMARY KEY,
  customer_id VARCHAR(32) NOT NULL REFERENCES customers(id),

  campground_id VARCHAR(32) NOT NULL REFERENCES campgrounds(id),
  campground_name_snapshot VARCHAR(200) NOT NULL,
  campground_region_snapshot VARCHAR(32),

  check_in DATE NOT NULL,
  check_out DATE NOT NULL,
  weekday_count INTEGER NOT NULL DEFAULT 0,
  holiday_count INTEGER NOT NULL DEFAULT 0,
  guest_count INTEGER NOT NULL DEFAULT 1,

  zone_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
  rental_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
  applied_discount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  final_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,

  CHECK (check_out > check_in),
  CHECK (zone_total >= 0),
  CHECK (rental_total >= 0),
  CHECK (applied_discount >= 0),
  CHECK (final_amount = zone_total + rental_total - applied_discount)
);
---
* 後端要自己查
---
SELECT name, region
FROM campgrounds
WHERE id = :campground_id;

campground_name_snapshot = campgrounds.name
campground_region_snapshot = campgrounds.region
---
* 查詢預約時，「成交當下資訊」，用 snapshot
* 顯示「目前營區最新資料」，才 JOIN 主檔
* 前端 DTO 可以維持不變


3. booking_selected_rentals
id 
booking_id
equipment_id
rental_sku_id
product_id
variant_id
sku ，快照 (保證資料不變動的話可以刪除)，規格識別碼
name，快照
`spec_label 快照文字顯示快照，用於顯示文字`
quantity
subtotal

## booking_selected_rentals 改動 :
保留 subtotal，但後端建立時重新計算

* 前端先算 subtotal，只作為 UX 顯示，結果放進 cart
---
perUnit =
  pricePerDayWeekday * weekdayCount +
  pricePerDayHoliday * holidayCount -
  discount;

subtotal = Math.max(perUnit, 0) * quantity;
---
* 前端送出 payload 給後端，後端重新查價格資料
根據 rentalSkuId、variantId、營區、日期等資訊查正式價格來源。
---
price_per_day_weekday
price_per_day_holiday
discount
stock
is_active
campground_id
---
* 後端重新計算 weekday / holiday
應用 checkIn / checkOut 和自己的假日規則重新計算：total_days, weekday_count, holiday_count
* 後端重新計算每筆 rental subtotal
---
per_unit =
  weekday_count * price_per_day_weekday
  + holiday_count * price_per_day_holiday
  - discount

rental_subtotal = max(per_unit, 0) * quantity
---
* 比對前端 subtotal，只作稽核或錯誤提示
---
if frontendSubtotal !== backendSubtotal:
  return 409 PRICE_CHANGED
---
* 寫入後端算好的值到資料庫
---
INSERT INTO booking_selected_rentals (
  booking_id,
  rental_sku_id,
  variant_id,
  sku,
  name,
  spec_label,
  quantity,
  subtotal
) VALUES (
  :booking_id,
  :rental_sku_id,
  :variant_id,
  :sku,
  :name_snapshot,
  :spec_label_snapshot,
  :quantity,
  :backend_calculated_subtotal
);
---
* 後端彙總 rental_total
---
rental_total = SUM(booking_selected_rentals.subtotal)
---
* 回傳後端確認後的 booking

## 同時保存租借/商品/變體 FK 與 sku、name、spec_label 的改動 :
* 保留 FK：rental_sku_id, variant_id
* 欄位改名成快照語意
sku → sku_snapshot
name → name_snapshot
spec_label → spec_label_snapshot
* 建立 booking 時，後端根據 FK 查主檔後寫入快照，不接受前端任意值。
* 查歷史預約時用 snapshot；查目前商品資訊時才 JOIN 主檔。


4. booking_history
id
booking_id
time 歷程發生時間
action 歷程文字，「已付款」、「已取消」、「已退款」。

