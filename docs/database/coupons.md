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
  code        VARCHAR(64) PRIMARY KEY,
  discount    NUMERIC(12, 2) NOT NULL,
  type        coupon_type NOT NULL DEFAULT 'fixed',
  min_order   NUMERIC(12, 2) NOT NULL DEFAULT 0,
  quantity    INTEGER NOT NULL DEFAULT 0,
  start_date  TIMESTAMPTZ,
  end_date    TIMESTAMPTZ,
  status      coupon_status NOT NULL DEFAULT 'active',
  category    coupon_category NOT NULL
);
---

2. order_coupons 改動：券使用紀錄，也就是 used 的真相來源。
---
CREATE TABLE order_coupons (
  id           BIGSERIAL PRIMARY KEY,
  order_id     BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  code         VARCHAR(64) NOT NULL,
  type         coupon_type,
  discount     NUMERIC(12, 2),
  amount       NUMERIC(12, 2),
  coupon_code  VARCHAR(64) REFERENCES coupons(code)
);
---

3. View
生成一個coupon_usage_stats 的虛擬表
可以顯示「已使用 / 剩餘」，但資料不是存在 coupons.used。
---
CREATE VIEW coupon_usage_stats AS
SELECT
  c.code,
  COUNT(o.id)::INTEGER AS used_count,
  GREATEST(c.quantity - COUNT(o.id), 0)::INTEGER AS remaining_count
FROM coupons c
LEFT JOIN order_coupons oc
  ON COALESCE(oc.coupon_code, oc.code) = c.code
LEFT JOIN orders o
  ON o.id = oc.order_id
 AND o.payment_status = 'paid'
 AND o.status IN ('unshipped', 'shipped', 'completed')
GROUP BY c.code, c.quantity;
---


* 回傳結果 :
{
  "code": "YURUIKAMP20",
  "discount": 200,
  "type": "fixed",
  "minOrder": 0,
  "quantity": 50,
  "used": 12,
  "remaining": 38,
  "startDate": "2026-06-01T00:00:00+08:00",
  "endDate": "2026-08-31T23:59:00+08:00",
  "status": "active",
  "category": "promotion"
}