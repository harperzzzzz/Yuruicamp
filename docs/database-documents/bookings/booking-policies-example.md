# 資料表實際互動
booking_policies
booking_policy_availability_statuses
booking_policy_occupying_statuses

## 建立全站預約政策
* booking_policies

id                          = 1
booking_window_days         = 90
advance_days                = 0
max_nights                  = 7
timezone                    = Asia/Taipei
date_boundary_hour          = 0
low_availability_threshold  = 30
created_at                  = 2026-07-16 09:00:00+08
updated_at                  = 2026-07-16 09:00:00+08

---
代表：
全站只使用一份預約政策。
使用者從今天起最多可預約 90 天內的日期。
無須提前天數，單筆最多住 7 晚。
時區採 Asia/Taipei；日期於 00:00 切換。
營位剩餘比例小於或等於 30% 時，前端顯示為低可用量。
---

## 設定可用性呈現狀態
* booking_policy_availability_statuses

policy_id  status
1          available
1          low
1          full
1          closed
1          out_of_window

---
代表：
政策 1 的可用性結果可使用 `available`、`low`、`full`、`closed`、`out_of_window` 表示。
每個狀態只會在同一政策中出現一次。
---

## 設定會占用營位的預約狀態
* booking_policy_occupying_statuses

policy_id  status
1          pending
1          confirmed
1          completed

---
代表：
狀態為待處理、已確認或已完成的預約，都會計入營位占用量。
取消的預約不在此表中，因此不會占用可訂數量。
---

## 三張表組合後的完整資料

資料庫查詢應以 `booking_policies.id = 1` 為主表，分別聚合兩張狀態關聯表，再轉換為前端的 camelCase DTO。

```json
{
  "bookingWindowDays": 90,
  "minLeadDays": 0,
  "maxStayNights": 7,
  "timezone": "Asia/Taipei",
  "dateBoundaryHour": 0,
  "occupyingStatuses": ["pending", "confirmed", "completed"],
  "availabilityStatuses": ["available", "low", "full", "closed", "out_of_window"],
  "dateRule": {
    "checkInInclusive": true,
    "checkOutExclusive": true
  },
  "availabilityStatus": {
    "lowThresholdRatio": 0.3
  }
}
```

---

欄位組合規則：
* `booking_window_days` → `bookingWindowDays`
* `advance_days` → `minLeadDays`
* `max_nights` → `maxStayNights`
* `date_boundary_hour` → `dateBoundaryHour`
* `low_availability_threshold / 100` → `availabilityStatus.lowThresholdRatio`
* `booking_policy_occupying_statuses.status[]` → `occupyingStatuses[]`
* `booking_policy_availability_statuses.status[]` → `availabilityStatuses[]`
* `dateRule.checkInInclusive` 與 `dateRule.checkOutExclusive` 是既有前端契約；目前資料庫未保存，正式 API 應固定輸出或另行建模。

## 實際前端資料流程
目前前端不是讀取上述三張 PostgreSQL 資料表，而是直接讀取 `data/admin/booking-policy.json`：

```json
{
  "bookingWindowDays": 90,
  "minLeadDays": 0,
  "maxStayNights": 7,
  "timezone": "Asia/Taipei",
  "occupyingStatuses": ["pending", "confirmed", "completed"],
  "dateRule": {
    "checkInInclusive": true,
    "checkOutExclusive": true
  },
  "availabilityStatus": {
    "lowThresholdRatio": 0.3
  }
}
```

`BookingAPI.getPolicy()` 讀取 JSON 後交給 `BookingAvailability.normalizePolicy()`；該函式會補齊預設值。`occupyingStatuses` 用於判斷預約是否扣減營位數量，`lowThresholdRatio` 用於回傳 `available`、`low` 或 `sold_out`。

目前 JSON 未輸出 `dateBoundaryHour` 與 `availabilityStatuses`，所以正式 API 接上資料庫時應先確認是否擴充前端契約。
