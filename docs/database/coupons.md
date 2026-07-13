# coupons
# order_coupons

## problems :
1. used 是可由券使用紀錄彙總得出的衍生資料。

## 主要更動 :
1. 改成資料庫 View / Materialized View
coupons：券主檔，只放不可由其他資料推導的欄位。
(移除實體 coupons.used)
---
CREATE TABLE coupons (
  id            BIGSERIAL PRIMARY KEY,
  code          VARCHAR(64) NOT NULL UNIQUE,
  discount      NUMERIC(12, 2) NOT NULL
                CHECK (discount >= 0),
  type          coupon_type NOT NULL DEFAULT 'fixed',
  min_order     NUMERIC(12, 2) NOT NULL DEFAULT 0
                CHECK (min_order >= 0),
  quantity      INTEGER NOT NULL DEFAULT 0
                CHECK (quantity >= 0),
  start_date    TIMESTAMPTZ,
  end_date      TIMESTAMPTZ,
  status        coupon_status NOT NULL DEFAULT 'active',
  category      coupon_category NOT NULL,

  CHECK (
    end_date IS NULL
    OR start_date IS NULL
    OR end_date >= start_date
  )
);
---

2. order_coupons 改動：券使用紀錄，也就是 used 的真相來源。
---
CREATE TABLE order_coupons (
  id            BIGSERIAL PRIMARY KEY,

  order_id      BIGINT NOT NULL
                REFERENCES orders(id)
                ON DELETE CASCADE,

  coupon_id     BIGINT
                REFERENCES coupons(id)
                ON DELETE SET NULL,

  coupon_code   VARCHAR(64) NOT NULL,

  type          coupon_type NOT NULL,
  discount      NUMERIC(12, 2) NOT NULL
                CHECK (discount >= 0),
  amount        NUMERIC(12, 2) NOT NULL DEFAULT 0
                CHECK (amount >= 0),

  UNIQUE (order_id, coupon_code)
);
---

3. View
生成一個coupon_usage_stats 的虛擬表
可以顯示「已使用 / 剩餘」，但資料不是存在 coupons.used。
---
CREATE VIEW coupon_usage_stats AS
SELECT
  c.id,
  c.code,
  c.quantity,
  COUNT(oc.id)::INTEGER AS used_count,
  GREATEST(c.quantity - COUNT(oc.id), 0)::INTEGER
    AS remaining_count
FROM coupons c
LEFT JOIN order_coupons oc
  ON oc.coupon_id = c.id
LEFT JOIN orders o
  ON o.id = oc.order_id
 AND o.payment_status = 'paid'
 AND o.status IN ('unshipped', 'shipped', 'completed')
GROUP BY
  c.id,
  c.code,
  c.quantity;
---
