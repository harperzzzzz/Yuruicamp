# campgrounds
# campground_closures

# OneToMany
campgrounds 1 : campground_closures N

## 主要更動 :
environment_tags, facility_tags 的JSONB 正規化

* 建議結構
campgrounds
  ├─ campground_environment_tags
  │    └─ environment_tags
  │
  └─ campground_facility_tags
       └─ facility_tags
       
## 建立環境標籤主表
---
CREATE TABLE environment_tags (
  id          BIGSERIAL PRIMARY KEY,
  code        VARCHAR(64) NOT NULL UNIQUE,
  name        VARCHAR(128) NOT NULL UNIQUE,
  description TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,

  CHECK (BTRIM(code) <> ''),
  CHECK (BTRIM(name) <> '')
);
---

## 建立設施標籤主表
---
CREATE TABLE facility_tags (
  id          BIGSERIAL PRIMARY KEY,
  code        VARCHAR(64) NOT NULL UNIQUE,
  name        VARCHAR(128) NOT NULL UNIQUE,
  description TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,

  CHECK (BTRIM(code) <> ''),
  CHECK (BTRIM(name) <> '')
);
---

## 建立營區與環境標籤關聯表
---
CREATE TABLE campground_environment_tags (
  campground_id VARCHAR(32) NOT NULL
                REFERENCES campgrounds(id)
                ON DELETE CASCADE,

  tag_id        BIGINT NOT NULL
                REFERENCES environment_tags(id)
                ON DELETE RESTRICT,

  PRIMARY KEY (campground_id, tag_id)
);

CREATE INDEX idx_campground_environment_tags_tag
  ON campground_environment_tags(tag_id);
---

## 建立營區與設施標籤關聯表
---
CREATE TABLE campground_facility_tags (
  campground_id VARCHAR(32) NOT NULL
                REFERENCES campgrounds(id)
                ON DELETE CASCADE,

  tag_id        BIGINT NOT NULL
                REFERENCES facility_tags(id)
                ON DELETE RESTRICT,

  PRIMARY KEY (campground_id, tag_id)
);

CREATE INDEX idx_campground_facility_tags_tag
  ON campground_facility_tags(tag_id);
---


## campgrounds 可預約營區主檔
移除environment_tags 欄位
移除facility_tags 欄位


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

