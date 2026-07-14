\set ON_ERROR_STOP on

CREATE TEMP TABLE p4_financial_issues (
  check_name TEXT NOT NULL,
  data_id TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p4_financial_issues
SELECT 'customer_spending_source', 'customers.total_spent',
       'cached customer spending column must not exist'
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'customers'
  AND column_name = 'total_spent';

INSERT INTO p4_financial_issues
SELECT 'order_header', source.id, 'source and normalized order amounts differ'
FROM migration.p4_order_source source
LEFT JOIN orders target ON target.id = source.id
WHERE target.id IS NULL
   OR target.subtotal IS DISTINCT FROM (source.payload->>'subtotal')::NUMERIC
   OR target.shipping_fee IS DISTINCT FROM (source.payload->>'shippingFee')::NUMERIC
   OR target.discount IS DISTINCT FROM (source.payload->>'discount')::NUMERIC
   OR target.total IS DISTINCT FROM (source.payload->>'total')::NUMERIC
   OR target.total IS DISTINCT FROM
        GREATEST(target.subtotal + target.shipping_fee - target.discount, 0);

WITH target_items AS (
  SELECT item.*,
         row_number() OVER (
           PARTITION BY item.order_id ORDER BY item.id
         )::INTEGER AS ordinal
  FROM order_items item
), source_items AS (
  SELECT source.id AS order_id, item.ordinality::INTEGER AS ordinal,
         item.value
  FROM migration.p4_order_source source
  CROSS JOIN LATERAL jsonb_array_elements(source.payload->'items')
    WITH ORDINALITY item(value, ordinality)
)
INSERT INTO p4_financial_issues
SELECT 'order_line', source.order_id || ':' || source.ordinal,
       'source line price/quantity or calculated amount differs'
FROM source_items source
LEFT JOIN target_items target
  ON target.order_id = source.order_id AND target.ordinal = source.ordinal
WHERE target.id IS NULL
   OR target.unit_price_snapshot IS DISTINCT FROM (source.value->>'price')::NUMERIC
   OR target.quantity IS DISTINCT FROM (source.value->>'quantity')::INTEGER;

INSERT INTO p4_financial_issues
SELECT 'order_subtotal', orders.id,
       format('header=%s detail=%s', orders.subtotal, detail.amount)
FROM orders
LEFT JOIN LATERAL (
  SELECT COALESCE(sum(item.unit_price_snapshot * item.quantity), 0)::NUMERIC(14, 2) AS amount
  FROM order_items item WHERE item.order_id = orders.id
) detail ON TRUE
WHERE orders.subtotal IS DISTINCT FROM detail.amount;

INSERT INTO p4_financial_issues
SELECT 'booking_header', source.id,
       'source and normalized booking summary amounts differ'
FROM migration.p4_booking_source source
LEFT JOIN bookings target ON target.id = source.id
WHERE target.id IS NULL
   OR target.zone_total IS DISTINCT FROM
        (source.payload->'summary'->>'zoneTotal')::NUMERIC
   OR target.rental_total IS DISTINCT FROM
        (source.payload->'summary'->>'rentalTotal')::NUMERIC
   OR target.applied_discount IS DISTINCT FROM
        (source.payload->'summary'->>'appliedDiscount')::NUMERIC
   OR target.final_amount IS DISTINCT FROM
        (source.payload->'summary'->>'finalAmount')::NUMERIC
   OR target.final_amount IS DISTINCT FROM GREATEST(
        target.zone_total + target.rental_total - target.applied_discount, 0
      );

WITH target_zones AS (
  SELECT detail.*,
         row_number() OVER (
           PARTITION BY detail.booking_id ORDER BY detail.id
         )::INTEGER AS ordinal
  FROM booking_selected_zones detail
), source_zones AS (
  SELECT source.id AS booking_id, zone.ordinality::INTEGER AS ordinal,
         zone.value
  FROM migration.p4_booking_source source
  CROSS JOIN LATERAL jsonb_array_elements(source.payload->'selectedZones')
    WITH ORDINALITY zone(value, ordinality)
)
INSERT INTO p4_financial_issues
SELECT 'booking_zone_line', source.booking_id || ':' || source.ordinal,
       format('stored=%s calculated=%s', source.value->>'subtotal',
         (booking.weekday_count * target.price_weekday_snapshot
          + booking.holiday_count * target.price_holiday_snapshot)
         * target.quantity)
FROM source_zones source
LEFT JOIN target_zones target
  ON target.booking_id = source.booking_id AND target.ordinal = source.ordinal
LEFT JOIN bookings booking ON booking.id = source.booking_id
WHERE target.id IS NULL OR booking.id IS NULL
   OR target.quantity IS DISTINCT FROM (source.value->>'quantity')::INTEGER
   OR (booking.weekday_count * target.price_weekday_snapshot
       + booking.holiday_count * target.price_holiday_snapshot)
      * target.quantity IS DISTINCT FROM (source.value->>'subtotal')::NUMERIC;

WITH target_rentals AS (
  SELECT detail.*,
         row_number() OVER (
           PARTITION BY detail.booking_id ORDER BY detail.id
         )::INTEGER AS ordinal
  FROM booking_selected_rentals detail
), source_rentals AS (
  SELECT source.id AS booking_id, rental.ordinality::INTEGER AS ordinal,
         rental.value
  FROM migration.p4_booking_source source
  CROSS JOIN LATERAL jsonb_array_elements(source.payload->'selectedRentals')
    WITH ORDINALITY rental(value, ordinality)
)
INSERT INTO p4_financial_issues
SELECT 'booking_rental_line', source.booking_id || ':' || source.ordinal,
       format('stored=%s calculated=%s', source.value->>'subtotal',
         GREATEST(
           booking.weekday_count * target.price_weekday_snapshot
           + booking.holiday_count * target.price_holiday_snapshot
           - target.discount_snapshot, 0
         ) * target.quantity)
FROM source_rentals source
LEFT JOIN target_rentals target
  ON target.booking_id = source.booking_id AND target.ordinal = source.ordinal
LEFT JOIN bookings booking ON booking.id = source.booking_id
WHERE target.id IS NULL OR booking.id IS NULL
   OR target.quantity IS DISTINCT FROM (source.value->>'quantity')::INTEGER
   OR GREATEST(
        booking.weekday_count * target.price_weekday_snapshot
        + booking.holiday_count * target.price_holiday_snapshot
        - target.discount_snapshot, 0
      ) * target.quantity IS DISTINCT FROM (source.value->>'subtotal')::NUMERIC;

INSERT INTO p4_financial_issues
SELECT 'booking_detail_total', booking.id,
       format('zone=%s/%s rental=%s/%s',
         booking.zone_total, totals.zone_amount,
         booking.rental_total, totals.rental_amount)
FROM bookings booking
LEFT JOIN LATERAL (
  SELECT
    (SELECT COALESCE(sum((
       booking.weekday_count * zone.price_weekday_snapshot
       + booking.holiday_count * zone.price_holiday_snapshot
     ) * zone.quantity), 0)
     FROM booking_selected_zones zone
     WHERE zone.booking_id = booking.id)::NUMERIC(14, 2) AS zone_amount,
    (SELECT COALESCE(sum(GREATEST(
       booking.weekday_count * rental.price_weekday_snapshot
       + booking.holiday_count * rental.price_holiday_snapshot
       - rental.discount_snapshot, 0
     ) * rental.quantity), 0)
     FROM booking_selected_rentals rental
     WHERE rental.booking_id = booking.id)::NUMERIC(14, 2) AS rental_amount
) totals ON TRUE
WHERE booking.zone_total IS DISTINCT FROM totals.zone_amount
   OR booking.rental_total IS DISTINCT FROM totals.rental_amount;

INSERT INTO p4_financial_issues
SELECT 'calendar_day_count', booking.id,
       format('stored=%s/%s official=%s/%s',
         booking.weekday_count, booking.holiday_count,
         resolved.weekday_count, resolved.holiday_count)
FROM bookings booking
LEFT JOIN LATERAL (
  SELECT count(*) FILTER (WHERE NOT is_holiday)::INTEGER AS weekday_count,
         count(*) FILTER (WHERE is_holiday)::INTEGER AS holiday_count
  FROM calendar_dates
  WHERE calendar_date >= booking.check_in AND calendar_date < booking.check_out
) resolved ON TRUE
WHERE booking.weekday_count IS DISTINCT FROM resolved.weekday_count
   OR booking.holiday_count IS DISTINCT FROM resolved.holiday_count;

WITH target_zones AS (
  SELECT detail.*,
         row_number() OVER (
           PARTITION BY detail.booking_id ORDER BY detail.id
         )::INTEGER AS ordinal
  FROM booking_selected_zones detail
), target_rentals AS (
  SELECT detail.*,
         row_number() OVER (
           PARTITION BY detail.booking_id ORDER BY detail.id
         )::INTEGER AS ordinal
  FROM booking_selected_rentals detail
)
INSERT INTO p4_financial_issues
SELECT 'price_evidence', data_id, reason
FROM (
  SELECT evidence.booking_id || ':' || evidence.zone_ordinal AS data_id,
         'zone chosen price differs from target snapshot' AS reason
  FROM migration.p4_zone_price_reconciliation evidence
  LEFT JOIN target_zones target
    ON target.booking_id = evidence.booking_id
   AND target.ordinal = evidence.zone_ordinal
  WHERE target.id IS NULL
     OR target.price_weekday_snapshot IS DISTINCT FROM evidence.chosen_weekday_price
     OR target.price_holiday_snapshot IS DISTINCT FROM evidence.chosen_holiday_price
  UNION ALL
  SELECT evidence.booking_id || ':' || evidence.rental_ordinal,
         'rental chosen price/discount differs from target snapshot'
  FROM migration.p4_rental_price_reconciliation evidence
  LEFT JOIN target_rentals target
    ON target.booking_id = evidence.booking_id
   AND target.ordinal = evidence.rental_ordinal
  WHERE target.id IS NULL
     OR target.price_weekday_snapshot IS DISTINCT FROM evidence.chosen_weekday_price
     OR target.price_holiday_snapshot IS DISTINCT FROM evidence.chosen_holiday_price
     OR target.discount_snapshot IS DISTINCT FROM evidence.chosen_discount
) invalid;

INSERT INTO p4_financial_issues
SELECT 'coupon_usage_stats', coupon.id::TEXT,
       format('used=%s remaining=%s issue=%s',
         stats.used_quantity, stats.remaining_quantity, coupon.issue_quantity)
FROM coupons coupon
LEFT JOIN coupon_usage_stats stats ON stats.coupon_id = coupon.id
WHERE stats.coupon_id IS NULL OR stats.used_quantity <> 0
   OR stats.remaining_quantity <> coupon.issue_quantity;

INSERT INTO p4_financial_issues
SELECT 'customer_spending', COALESCE(expected.customer_id, actual.customer_id),
       format('expected=%s actual=%s', expected.total_spent, actual.total_spent)
FROM (
  SELECT customer_id, sum(total)::NUMERIC(14, 2) AS total_spent
  FROM orders
  WHERE payment_status = 'paid' AND status = 'completed'
    AND refund_status = 'none'
  GROUP BY customer_id
) expected
FULL JOIN customer_spending_summary actual USING (customer_id)
WHERE expected.total_spent IS DISTINCT FROM actual.total_spent;

INSERT INTO p4_financial_issues
SELECT 'product_stock_summary', product_id,
       format('onHand=%s/%s reserved=%s/%s available=%s/%s',
         actual.total_on_hand, raw.total_on_hand,
         actual.total_reserved, raw.total_reserved,
         actual.total_available, expected.total_available)
FROM product_stock_summary actual
JOIN LATERAL (
  SELECT
    COALESCE((SELECT sum(stock.on_hand_quantity)
      FROM product_variants variant
      JOIN inventory_stocks stock ON stock.variant_id = variant.id
      WHERE variant.product_id = actual.product_id), 0)::BIGINT AS total_on_hand,
    COALESCE((SELECT sum(reservation.quantity)
      FROM product_stock_reservations reservation
      JOIN product_variants variant ON variant.id = reservation.variant_id
      WHERE variant.product_id = actual.product_id
        AND reservation.status = 'active'), 0)::BIGINT AS total_reserved
) raw ON TRUE
CROSS JOIN LATERAL (
  SELECT raw.total_on_hand - raw.total_reserved AS total_available
) expected
WHERE actual.total_on_hand <> raw.total_on_hand
   OR actual.total_reserved <> raw.total_reserved
   OR actual.total_available <> expected.total_available
   OR actual.total_available < 0;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'amounts', jsonb_build_object(
    'orderSubtotal', (SELECT sum(subtotal) FROM orders),
    'orderTotal', (SELECT sum(total) FROM orders),
    'bookingZoneTotal', (SELECT sum(zone_total) FROM bookings),
    'bookingRentalTotal', (SELECT sum(rental_total) FROM bookings),
    'bookingFinalAmount', (SELECT sum(final_amount) FROM bookings),
    'zonePriceFallbacks', (SELECT count(*) FROM migration.p4_zone_price_reconciliation
      WHERE disposition_status = 'APPROVED_FALLBACK'),
    'rentalPriceFallbacks', (SELECT count(*) FROM migration.p4_rental_price_reconciliation
      WHERE disposition_status = 'APPROVED_FALLBACK')
  ),
  'issues', COALESCE(jsonb_agg(jsonb_build_object(
    'check', check_name, 'id', data_id, 'reason', reason
  ) ORDER BY check_name, data_id), '[]'::JSONB)
))
FROM p4_financial_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p4_financial_issues) THEN
    RAISE EXCEPTION 'P4 financial validation failed with % issue(s)',
      (SELECT count(*) FROM p4_financial_issues);
  END IF;
END $$;
