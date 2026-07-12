# campgrounds
# campground_closures

# OneToMany
campgrounds 1 : campground_closures N


1. campgrounds 可預約營區主檔
id 
name
region 區域
description
environment_tags
facility_tags 設施標籤


2. campground_closures 營區公休 / 關閉
id
campground_id
type ，enum 只有 date_range 和 weekly
start_date 前端range 搜尋用
end_date 前端range 搜尋用
day_of_week 標記當周星期幾公休 (0 - 6)
effective_from 標記公休生效
effective_to 標記公休失效
reason
created_by 建立者
created_at 預設 NOW()

## 整個表的用意 :
{
  "id": "CL002",
  "campgroundId": "C003",
  "type": "weekly",
  "dayOfWeek": 2,
  "effectiveFrom": "2026-07-09",
  "effectiveTo": "2026-09-30",
  "reason": "每週二公休"
}
C003 這個營區，在 2026-07-09 到 2026-09-30 這段期間內，只要日期是星期二，就視為公休。公休命中時，整個營區所有 zone 都不能預約。
