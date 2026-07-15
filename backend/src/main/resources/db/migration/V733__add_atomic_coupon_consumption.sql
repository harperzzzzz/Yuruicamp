-- Prevent concurrent checkouts from consuming more coupons than issued.
-- The application must update this counter and insert order_coupons in the
-- same database transaction.

ALTER TABLE coupons
  ADD COLUMN consumed_quantity INTEGER NOT NULL DEFAULT 0;

UPDATE coupons coupon
SET consumed_quantity = usage.used_quantity::INTEGER
FROM coupon_usage_stats usage
WHERE usage.coupon_id = coupon.id;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM coupons
    WHERE consumed_quantity < 0
       OR consumed_quantity > issue_quantity
  ) THEN
    RAISE EXCEPTION
      'V733 guard: existing coupon consumption is outside issue quantity';
  END IF;
END
$$;

ALTER TABLE coupons
  ADD CONSTRAINT ck_coupons_consumed_quantity CHECK (
    consumed_quantity >= 0
    AND consumed_quantity <= issue_quantity
  );

COMMENT ON COLUMN coupons.consumed_quantity IS
  'Atomic checkout allocation counter; update only inside the order transaction.';
