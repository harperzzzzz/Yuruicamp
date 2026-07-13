# campgrounds
# campground_zones
# booking_selected_zones
# zone_blocks

# OneToMany
campgrounds 1 : campground_zones N
campground_zones 1 : booking_selected_zones
campground_zones 1 : zone_blocks

## problems : 
booking_selected_zones.subtotal 可由數量與價格資料推導的金額。
---


1. campground_zones 營位主檔
id
campground_id
type
capacity_per_site 可容納的人數
price_weekday
price_holiday
total_sites 每天可賣的最大營位數


2. booking_selected_zones 被預約的營位區
id 明細流水號
booking_id
zone_id
zone_type 保留為成交快照，不作為查詢關聯依據。
quantity
subtotal 彙總到 bookings.zone_total

## booking_selected_zones 更動 :
* booking_selected_zones.subtotal 移除，改存成交當下的價格快照：
---
CREATE TABLE booking_selected_zones (
  id BIGSERIAL PRIMARY KEY,
  booking_id BIGINT NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  zone_id VARCHAR(32) NOT NULL REFERENCES campground_zones(id),
  zone_type VARCHAR(64),
  quantity INTEGER NOT NULL CHECK (quantity > 0),

  price_weekday_snapshot NUMERIC(12, 2) NOT NULL CHECK (price_weekday_snapshot >= 0),
  price_holiday_snapshot NUMERIC(12, 2) NOT NULL CHECK (price_holiday_snapshot >= 0)
);
---
* 建立 booking 時的後端流程
查price_weekday / price_holiday > 依 checkIn / checkOut 重新算 > 寫入快照 > 用快照計算 zone_total
---
const zone = await getCampgroundZone(zoneId);

const zoneLineTotal =
  (weekdayCount * zone.priceWeekday + holidayCount * zone.priceHoliday)
  * quantity;

await insertBookingSelectedZone({
  bookingId,
  zoneId,
  zoneType: zone.type,
  quantity,
  priceWeekdaySnapshot: zone.priceWeekday,
  priceHolidaySnapshot: zone.priceHoliday,
});

booking.zoneTotal = sum(zoneLineTotal);
---
* 查詢 booking 時補回顯示用 subtotal (也可由spring boot 完成)
---
SELECT
  bsz.*,
  (
    (b.weekday_count * bsz.price_weekday_snapshot)
    + (b.holiday_count * bsz.price_holiday_snapshot)
  ) * bsz.quantity AS subtotal
FROM booking_selected_zones bsz
JOIN bookings b ON b.id = bsz.booking_id;
---
* 前端很多地方直接讀 z.subtotal，可以先做 helper，避免到處改公式
---
function getZoneSubtotal(zone, bookingInfo) {
  if (zone.subtotal != null) return Number(zone.subtotal) || 0;

  const weekday = Number(bookingInfo.weekdayCount) || 0;
  const holiday = Number(bookingInfo.holidayCount) || 0;
  const qty = Number(zone.quantity) || 0;

  return (
    weekday * Number(zone.priceWeekdaySnapshot || 0) +
    holiday * Number(zone.priceHolidaySnapshot || 0)
  ) * qty;
}
---
z.subtotal 改成 getZoneSubtotal(z, bookingCart.bookingInfo)
要改的位置 :
booking/js/booking-cart.js
booking/js/booking-checkout.js
booking/js/booking-header.js
admin/js/bookings.js
js/components/member-center.js

* 購物車數量調整改法
booking-cart.js : 改成不寫 subtotal
---
var zoneTotal = zones.reduce(function (sum, z) {
  return sum + getZoneSubtotal(z, bookingCart.bookingInfo);
}, 0);
---
* 舊資料相容
---
if (zone.priceWeekdaySnapshot == null && zone.subtotal != null) {
  // legacy fallback，只為舊資料顯示
  return Number(zone.subtotal) || 0;
}
---

* 資料庫 View / 查詢層提供 subtotal
* 後端不放subtotal
---
@Entity
@Table(name = "booking_selected_zones")
public class BookingSelectedZone {

    @Id
    private Long id;

    private String zoneId;
    private String zoneType;
    private Integer quantity;

    private BigDecimal priceWeekdaySnapshot;
    private BigDecimal priceHolidaySnapshot;

    @ManyToOne
    @JoinColumn(name = "booking_id")
    private Booking booking;
}
---
* Response DTO 放 subtotal
---
public record BookingSelectedZoneResponse(
    String zoneId,
    String zoneType,
    Integer quantity,
    BigDecimal priceWeekdaySnapshot,
    BigDecimal priceHolidaySnapshot,
    BigDecimal subtotal
) {}
---
* Service 組 response 時即時計算
---
private BookingSelectedZoneResponse toZoneResponse(
    BookingSelectedZone zone,
    Booking booking
) {
    BigDecimal weekdayAmount = zone.getPriceWeekdaySnapshot()
        .multiply(BigDecimal.valueOf(booking.getWeekdayCount()));

    BigDecimal holidayAmount = zone.getPriceHolidaySnapshot()
        .multiply(BigDecimal.valueOf(booking.getHolidayCount()));

    BigDecimal subtotal = weekdayAmount
        .add(holidayAmount)
        .multiply(BigDecimal.valueOf(zone.getQuantity()));

    return new BookingSelectedZoneResponse(
        zone.getZoneId(),
        zone.getZoneType(),
        zone.getQuantity(),
        zone.getPriceWeekdaySnapshot(),
        zone.getPriceHolidaySnapshot(),
        subtotal
    );
}

公式 : (price_weekday_snapshot * weekday_count + price_holiday_snapshot * holiday_count) * quantity
---
* Booking Response 一起回傳
---
public record BookingResponse(
    Long id,
    Integer weekdayCount,
    Integer holidayCount,
    List<BookingSelectedZoneResponse> selectedZones,
    BigDecimal zoneTotal
) {}
---
Service :
public BookingResponse getBooking(Long bookingId) {
    Booking booking = bookingRepository.findById(bookingId)
        .orElseThrow();

    List<BookingSelectedZoneResponse> zones = booking.getSelectedZones()
        .stream()
        .map(zone -> toZoneResponse(zone, booking))
        .toList();

    BigDecimal zoneTotal = zones.stream()
        .map(BookingSelectedZoneResponse::subtotal)
        .reduce(BigDecimal.ZERO, BigDecimal::add);

    return new BookingResponse(
        booking.getId(),
        booking.getWeekdayCount(),
        booking.getHolidayCount(),
        zones,
        zoneTotal
    );
}
---
* 前端前端照樣使用 z.subtotal
* 前端可以送 subtotal，但後端不要信任它。後端應該自己查 campground_zones 價格，寫入快照：
---
BookingSelectedZone selectedZone = new BookingSelectedZone();

selectedZone.setZoneId(zone.getId());
selectedZone.setZoneType(zone.getType());
selectedZone.setQuantity(request.quantity());
selectedZone.setPriceWeekdaySnapshot(zone.getPriceWeekday());
selectedZone.setPriceHolidaySnapshot(zone.getPriceHoliday());
selectedZone.setBooking(booking);
---


3. zone_blocks 營位區的供給例外
id 封鎖紀錄識別碼
campground_id
zone_id
start_date
end_date
blocked_sites 扣減的可賣營位數，目前 DDL 沒有限制其最大值
reason
created_by 建立者 (可刪掉? 營地的設定權)
    * 更改成created_by VARCHAR(32) NOT NULL REFERENCES admin_users(id) ON DELETE RESTRICT
    * 指向後台員工
    * 把 zone-blocks.json 的 createdBy: "admin" 改成真實 admin user id，例如 "01"
    * 在 admin_users seed 補一筆 id = "admin" 的系統管理員。
created_at
