# campgrounds
# campground_closures

# OneToMany
campgrounds 1 : campground_closures N

## 主要更動 :
* 補強規則 (來源: [data/catalog/campgrounds.json (line 1)])
目的：避免 NULL、物件、字串、數字誤寫進去。
---
environment_tags JSONB NOT NULL DEFAULT '[]'::jsonb,
facility_tags    JSONB NOT NULL DEFAULT '[]'::jsonb

CHECK (jsonb_typeof(environment_tags) = 'array'),
CHECK (jsonb_typeof(facility_tags) = 'array')
---

* 查詢條件使用 JSONB containment (目前查詢為AND)
SQL 對應：
---
SELECT *
FROM campgrounds
WHERE environment_tags @> '["高海拔", "森林系"]'::jsonb
  AND facility_tags @> '["獨立衛浴"]'::jsonb;


如果只有單一 tag：
WHERE environment_tags @> '["高海拔"]'::jsonb
---

* 加上索引提升效率 (改成or 要更改index 預設)
---
CREATE INDEX idx_campgrounds_environment_tags
ON campgrounds
USING GIN (environment_tags jsonb_path_ops);

CREATE INDEX idx_campgrounds_facility_tags
ON campgrounds
USING GIN (facility_tags jsonb_path_ops);
---

* 加資料驗證清單
---
SELECT id
FROM campgrounds
WHERE jsonb_typeof(environment_tags) <> 'array'
   OR jsonb_typeof(facility_tags) <> 'array';

SELECT id
FROM campgrounds
WHERE environment_tags IS NULL
   OR facility_tags IS NULL;

檢查非字串元素：
SELECT id, environment_tags
FROM campgrounds
WHERE EXISTS (
  SELECT 1
  FROM jsonb_array_elements(environment_tags) AS tag(value)
  WHERE jsonb_typeof(tag.value) <> 'string'
);
SELECT id, facility_tags
FROM campgrounds
WHERE EXISTS (
  SELECT 1
  FROM jsonb_array_elements(facility_tags) AS tag(value)
  WHERE jsonb_typeof(tag.value) <> 'string'
);
---


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
  * 改成 created_by VARCHAR(32) NOT NULL REFERENCES admin_users(id) ON DELETE RESTRICT

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

