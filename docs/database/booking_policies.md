# booking_policies

## problems :
1. occupying_statuses、
2. date_rule、
3. availability_status 以 JSONB 存放規則集合。
違反1NF


### 主要更動 :
三個 JSONB 欄位都可以拆除，讓資料符合較嚴格的 1NF

occupying_statuses   → 子表，一個狀態一列
date_rule            → 直接拆成布林欄位
availability_status  → 直接拆成數值欄位

## 1. booking_policies 更動
---
CREATE TABLE booking_policies (
  id                         SMALLINT PRIMARY KEY
                             CHECK (id = 1),

  booking_window_days       INTEGER NOT NULL DEFAULT 90
                             CHECK (booking_window_days > 0),

  min_lead_days              INTEGER NOT NULL DEFAULT 0
                             CHECK (min_lead_days >= 0),

  max_stay_nights            INTEGER NOT NULL DEFAULT 7
                             CHECK (max_stay_nights > 0),

  timezone                   VARCHAR(64) NOT NULL DEFAULT 'Asia/Taipei'
                             CHECK (BTRIM(timezone) <> ''),

  check_in_inclusive         BOOLEAN NOT NULL DEFAULT TRUE,

  check_out_exclusive        BOOLEAN NOT NULL DEFAULT TRUE,

  low_threshold_ratio        NUMERIC(5, 4)
                             CHECK (
                               low_threshold_ratio IS NULL
                               OR (
                                 low_threshold_ratio >= 0
                                 AND low_threshold_ratio <= 1
                               )
                             ),

  created_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
---


## 拆出 occupying_statuses
---
CREATE TABLE booking_policy_occupying_statuses (
  policy_id     SMALLINT NOT NULL
                REFERENCES booking_policies(id)
                ON DELETE CASCADE,

  status        booking_status NOT NULL,

  PRIMARY KEY (policy_id, status)
);
---

## 拆出 availability_status
目前
"availabilityStatus": {
  "lowThresholdRatio": 0.3
}
變成：
{
  "lowThresholdRatio": 0.3
}

