# E-2 Booking 可用性查詢

## 用途

讓前台在進入 Booking Checkout 前，查詢住宿期間每個營位的最低剩餘量。這個端點不建立預約，也不鎖位。

## 流程

```text
POST /api/booking/check-availability
→ 驗證日期與 Asia/Taipei 預約政策
→ 確認營區與 zones 有效
→ get_zone_availability(checkIn, checkOut - 1 day)
→ 取每個 zone 跨晚最低剩餘量
→ 回傳 available、reasons、zones
```

## 規則

- 日期區間採 `[checkIn, checkOut)`；退房日不占位。
- `checkIn` 必須落在 `today + advanceDays` 至 `today + bookingWindowDays`，且晚數不得超過 `maxNights`。
- 公休回 `CAMPGROUND_CLOSED`；停售或 pending／confirmed 占用造成不足時回 `ZONE_UNAVAILABLE`。
- 不可訂仍回 HTTP 200 與 `available=false`；日期／政策錯誤才回 400。
- 同一 zone 的 `availableQuantity` 是整段期間每天剩餘量的最小值。

## 驗證結果

- `BookingAvailabilityIntegrationTest` 在只有完整 Schema、沒有 dev seed 的 PostgreSQL 執行 11 項，全部通過。
- 已驗證正常可訂、日期格式、同日入住退房、最少提前天數、90 天窗口、最大晚數、公休、zone block、pending／confirmed 占用與多晚最低量。
- 測試採交易回滾；驗證後營區、預約與 policy 殘留皆為 0。
