\set ON_ERROR_STOP on

CREATE TEMP TABLE p4_data_issues (
  check_name TEXT NOT NULL,
  data_id TEXT NOT NULL,
  reason TEXT NOT NULL
);

WITH expected(check_name, expected_count, actual_count) AS (
  VALUES
    ('orders', (SELECT count(*) FROM migration.p4_order_source),
      (SELECT count(*) FROM orders)),
    ('order_items',
      (SELECT COALESCE(sum(jsonb_array_length(payload->'items')), 0)
       FROM migration.p4_order_source),
      (SELECT count(*) FROM order_items)),
    ('order_history',
      (SELECT COALESCE(sum(jsonb_array_length(payload->'history')), 0)
       FROM migration.p4_order_source),
      (SELECT count(*) FROM order_status_history)),
    ('coupons', (SELECT count(*) FROM migration.p4_coupon_source),
      (SELECT count(*) FROM coupons)),
    ('order_coupons', 0::BIGINT, (SELECT count(*) FROM order_coupons)),
    ('coupon_adjustments', 0::BIGINT,
      (SELECT count(*) FROM coupon_usage_adjustments)),
    ('calendar_dates', 365::BIGINT, (SELECT count(*) FROM calendar_dates)),
    ('bookings', (SELECT count(*) FROM migration.p4_booking_source),
      (SELECT count(*) FROM bookings)),
    ('booking_zones',
      (SELECT COALESCE(sum(jsonb_array_length(payload->'selectedZones')), 0)
       FROM migration.p4_booking_source),
      (SELECT count(*) FROM booking_selected_zones)),
    ('booking_rentals',
      (SELECT COALESCE(sum(jsonb_array_length(payload->'selectedRentals')), 0)
       FROM migration.p4_booking_source),
      (SELECT count(*) FROM booking_selected_rentals)),
    ('booking_history',
      (SELECT COALESCE(sum(jsonb_array_length(payload->'history')), 0)
       FROM migration.p4_booking_source),
      (SELECT count(*) FROM booking_status_history)),
    ('product_reservations', 0::BIGINT,
      (SELECT count(*) FROM product_stock_reservations)),
    ('rental_reservations', 21::BIGINT,
      (SELECT count(*) FROM rental_stock_reservations)),
    ('rental_quarantine', 19::BIGINT,
      (SELECT count(*) FROM migration.p4_rental_reservation_quarantine)),
    ('snapshot_fallbacks',
      (3 * (SELECT count(*) FROM migration.p4_order_source)
       + (SELECT count(*) FROM migration.p4_coupon_source))::BIGINT,
      (SELECT count(*) FROM migration.p4_snapshot_fallbacks))
)
INSERT INTO p4_data_issues
SELECT 'row_count', check_name,
       format('expected=%s actual=%s', expected_count, actual_count)
FROM expected
WHERE expected_count <> actual_count;

INSERT INTO p4_data_issues
SELECT 'orphan', data_id, reason
FROM (
  SELECT orders.id AS data_id, 'order customer does not resolve' AS reason
  FROM orders LEFT JOIN customers ON customers.id = orders.customer_id
  WHERE customers.id IS NULL
  UNION ALL
  SELECT item.id::TEXT, 'order item order/product/variant does not resolve'
  FROM order_items item
  LEFT JOIN orders ON orders.id = item.order_id
  LEFT JOIN products ON products.id = item.product_id
  LEFT JOIN product_variants variant
    ON variant.id = item.variant_id AND variant.product_id = item.product_id
  WHERE orders.id IS NULL OR products.id IS NULL OR variant.id IS NULL
  UNION ALL
  SELECT history.id::TEXT, 'order history order or actor does not resolve'
  FROM order_status_history history
  LEFT JOIN orders ON orders.id = history.order_id
  LEFT JOIN admin_users actor ON actor.id = history.actor_id
  WHERE orders.id IS NULL OR (history.actor_id IS NOT NULL AND actor.id IS NULL)
  UNION ALL
  SELECT booking.id, 'booking customer or campground does not resolve'
  FROM bookings booking
  LEFT JOIN customers ON customers.id = booking.customer_id
  LEFT JOIN campgrounds ON campgrounds.id = booking.campground_id
  WHERE customers.id IS NULL OR campgrounds.id IS NULL
  UNION ALL
  SELECT detail.id::TEXT, 'booking zone parent or zone does not resolve'
  FROM booking_selected_zones detail
  LEFT JOIN bookings ON bookings.id = detail.booking_id
  LEFT JOIN campground_zones zone
    ON zone.id = detail.zone_id AND zone.campground_id = bookings.campground_id
  WHERE bookings.id IS NULL OR zone.id IS NULL
  UNION ALL
  SELECT detail.id::TEXT,
         'booking rental parent/listing/variant/campground mapping does not resolve'
  FROM booking_selected_rentals detail
  LEFT JOIN bookings ON bookings.id = detail.booking_id
  LEFT JOIN rental_listings listing
    ON listing.id = detail.rental_listing_id
   AND listing.campground_id = bookings.campground_id
   AND listing.rental_sku_variant_id = detail.rental_sku_variant_id
  LEFT JOIN rental_sku_variants variant
    ON variant.id = detail.rental_sku_variant_id
  WHERE bookings.id IS NULL OR listing.id IS NULL OR variant.id IS NULL
  UNION ALL
  SELECT history.id::TEXT, 'booking history booking or actor does not resolve'
  FROM booking_status_history history
  LEFT JOIN bookings ON bookings.id = history.booking_id
  LEFT JOIN admin_users actor ON actor.id = history.actor_id
  WHERE bookings.id IS NULL OR (history.actor_id IS NOT NULL AND actor.id IS NULL)
  UNION ALL
  SELECT reservation.id::TEXT,
         'rental reservation detail/variant/location does not resolve'
  FROM rental_stock_reservations reservation
  LEFT JOIN booking_selected_rentals detail
    ON detail.id = reservation.booking_selected_rental_id
   AND detail.rental_sku_variant_id = reservation.rental_sku_variant_id
  LEFT JOIN inventory_locations location ON location.id = reservation.location_id
  WHERE detail.id IS NULL OR location.id IS NULL
) invalid;

INSERT INTO p4_data_issues
SELECT 'reconciliation_disposition', data_id, reason
FROM (
  SELECT booking_id AS data_id,
         'calendar resolution is unresolved or missing chosen counts' AS reason
  FROM migration.p4_booking_day_count_resolution
  WHERE disposition_status NOT IN ('MATCHED', 'APPROVED_FALLBACK')
     OR resolved_weekday_count IS NULL OR resolved_holiday_count IS NULL
  UNION ALL
  SELECT booking_id || ':' || zone_ordinal,
         'zone price resolution is unresolved or missing chosen prices'
  FROM migration.p4_zone_price_reconciliation
  WHERE disposition_status NOT IN ('MATCHED', 'APPROVED_FALLBACK')
     OR chosen_weekday_price IS NULL OR chosen_holiday_price IS NULL
  UNION ALL
  SELECT booking_id || ':' || rental_ordinal,
         'rental price resolution is unresolved or missing chosen values'
  FROM migration.p4_rental_price_reconciliation
  WHERE disposition_status NOT IN ('MATCHED', 'APPROVED_FALLBACK')
     OR chosen_weekday_price IS NULL OR chosen_holiday_price IS NULL
     OR chosen_discount IS NULL
  UNION ALL
  SELECT booking_id || ':' || rental_ordinal,
         'reservation quarantine lacks an approved reason code'
  FROM migration.p4_rental_reservation_quarantine
  WHERE disposition_status <> 'APPROVED_QUARANTINE'
     OR reason_code NOT IN ('STALE_ACTIVE_PAST', 'FUTURE_CAPACITY_CONFLICT')
) invalid;

WITH selected AS (
  SELECT detail.*,
         row_number() OVER (
           PARTITION BY detail.booking_id ORDER BY detail.id
         )::INTEGER AS rental_ordinal
  FROM booking_selected_rentals detail
), dispositions AS (
  SELECT selected.booking_id, selected.rental_ordinal,
         reservation.rental_sku_variant_id, reservation.location_id,
         reservation.quantity, 'target'::TEXT AS disposition
  FROM rental_stock_reservations reservation
  JOIN selected ON selected.id = reservation.booking_selected_rental_id
  UNION ALL
  SELECT booking_id, rental_ordinal, rental_sku_variant_id, location_id,
         quantity, 'quarantine'
  FROM migration.p4_rental_reservation_quarantine
), source AS (
  SELECT booking.id AS booking_id, rental.ordinality::INTEGER AS rental_ordinal,
         rental.value->>'variantId' AS rental_sku_variant_id,
         booking.payload->'bookingInfo'->>'campgroundId' AS location_id,
         (rental.value->>'quantity')::INTEGER AS quantity
  FROM migration.p4_booking_source booking
  CROSS JOIN LATERAL jsonb_array_elements(
    booking.payload->'selectedRentals'
  ) WITH ORDINALITY rental(value, ordinality)
)
INSERT INTO p4_data_issues
SELECT 'reservation_reconciliation',
       source.booking_id || ':' || source.rental_ordinal,
       format('dispositions=%s', count(dispositions.*))
FROM source
LEFT JOIN dispositions
  ON dispositions.booking_id = source.booking_id
 AND dispositions.rental_ordinal = source.rental_ordinal
 AND dispositions.rental_sku_variant_id = source.rental_sku_variant_id
 AND dispositions.location_id = source.location_id
 AND dispositions.quantity = source.quantity
GROUP BY source.booking_id, source.rental_ordinal
HAVING count(dispositions.*) <> 1;

WITH active_usage AS (
  SELECT reservation.rental_sku_variant_id, reservation.location_id,
         day_value::DATE AS reserved_date,
         sum(reservation.quantity) AS reserved_quantity
  FROM rental_stock_reservations reservation
  CROSS JOIN LATERAL generate_series(
    reservation.check_in, reservation.check_out - 1, INTERVAL '1 day'
  ) day_value
  WHERE reservation.status = 'active'
  GROUP BY reservation.rental_sku_variant_id,
           reservation.location_id, day_value::DATE
)
INSERT INTO p4_data_issues
SELECT 'rental_capacity',
       usage.rental_sku_variant_id || ':' || usage.location_id || ':' || usage.reserved_date,
       format('reserved=%s onHand=%s', usage.reserved_quantity, stock.on_hand_quantity)
FROM active_usage usage
LEFT JOIN rental_sku_variant_stocks stock
  ON stock.rental_sku_variant_id = usage.rental_sku_variant_id
 AND stock.location_id = usage.location_id
WHERE stock.rental_sku_variant_id IS NULL
   OR usage.reserved_quantity > stock.on_hand_quantity;

INSERT INTO p4_data_issues
SELECT 'reservation_status_count', 'rental_stock_reservations',
       format('active=%s terminal=%s',
         count(*) FILTER (WHERE status = 'active'),
         count(*) FILTER (WHERE status IN ('released', 'fulfilled')))
FROM rental_stock_reservations
HAVING count(*) FILTER (WHERE status = 'active') <> 3
    OR count(*) FILTER (WHERE status IN ('released', 'fulfilled')) <> 18;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'counts', jsonb_build_object(
    'orders', (SELECT count(*) FROM orders),
    'orderItems', (SELECT count(*) FROM order_items),
    'orderHistory', (SELECT count(*) FROM order_status_history),
    'coupons', (SELECT count(*) FROM coupons),
    'bookings', (SELECT count(*) FROM bookings),
    'bookingZones', (SELECT count(*) FROM booking_selected_zones),
    'bookingRentals', (SELECT count(*) FROM booking_selected_rentals),
    'bookingHistory', (SELECT count(*) FROM booking_status_history),
    'productReservations', (SELECT count(*) FROM product_stock_reservations),
    'rentalReservations', (SELECT count(*) FROM rental_stock_reservations),
    'rentalQuarantine',
      (SELECT count(*) FROM migration.p4_rental_reservation_quarantine)
  ),
  'issues', COALESCE(jsonb_agg(jsonb_build_object(
    'check', check_name, 'id', data_id, 'reason', reason
  ) ORDER BY check_name, data_id), '[]'::JSONB)
))
FROM p4_data_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p4_data_issues) THEN
    RAISE EXCEPTION 'P4 data validation failed with % issue(s)',
      (SELECT count(*) FROM p4_data_issues);
  END IF;
END $$;
