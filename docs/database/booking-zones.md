# campgrounds
# campground_zones
# booking_selected_zones
# zone_blocks

# OneToMany
campgrounds 1 : campground_zones N
campground_zones 1 : booking_selected_zones
campground_zones 1 : zone_blocks


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
zone_type 區域類型快照
quantity
subtotal 彙總到 bookings.zone_total


3. zone_blocks 營位區的供給例外
id 封鎖紀錄識別碼
campground_id
zone_id
start_date
end_date
blocked_sites 扣減的可賣營位數，目前 DDL 沒有限制其最大值
reason
created_by 建立者 (可刪掉? 營地的設定權)
created_at
