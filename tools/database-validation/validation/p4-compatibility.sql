\set ON_ERROR_STOP on

CREATE TEMP TABLE p4_compatibility_issues (
  check_name TEXT NOT NULL,
  data_id TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p4_compatibility_issues
SELECT 'order_dto', source.id,
       'normalized order scalar/snapshot fields differ from source DTO'
FROM migration.p4_order_source source
LEFT JOIN orders target ON target.id = source.id
LEFT JOIN customers customer ON customer.id = source.payload->>'customerId'
WHERE target.id IS NULL
   OR target.customer_id IS DISTINCT FROM source.payload->>'customerId'
   OR target.buyer_name_snapshot IS DISTINCT FROM source.payload->>'buyerName'
   OR target.buyer_email_snapshot IS DISTINCT FROM customer.email
   OR target.recipient_name_snapshot IS DISTINCT FROM source.payload->>'buyerName'
   OR target.shipping_address_snapshot IS DISTINCT FROM source.payload->>'address'
   OR target.shipping_phone_snapshot IS DISTINCT FROM customer.phone
   OR target.payment_method IS DISTINCT FROM
        CASE WHEN source.payload->>'payment' = 'cod' THEN 'cod' ELSE 'online' END
   OR target.payment_status IS DISTINCT FROM source.payload->>'paymentStatus'
   OR target.status IS DISTINCT FROM source.payload->>'status'
   OR target.refund_status IS DISTINCT FROM
        CASE WHEN source.payload->>'status' = 'returned' THEN 'approved' ELSE 'none' END
   OR target.placed_at IS DISTINCT FROM
        ((source.payload->>'createdAt') || '+08:00')::TIMESTAMPTZ;

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
INSERT INTO p4_compatibility_issues
SELECT 'order_item_dto', source.order_id || ':' || source.ordinal,
       'normalized order item snapshot differs from source DTO'
FROM source_items source
LEFT JOIN target_items target
  ON target.order_id = source.order_id AND target.ordinal = source.ordinal
WHERE target.id IS NULL
   OR target.product_id IS DISTINCT FROM source.value->>'productId'
   OR target.variant_id IS DISTINCT FROM source.value->>'variantId'
   OR target.sku_snapshot IS DISTINCT FROM source.value->>'sku'
   OR target.product_name_snapshot IS DISTINCT FROM source.value->>'name'
   OR target.specification_snapshot IS DISTINCT FROM COALESCE(
        NULLIF(source.value->>'specLabel', ''),
        NULLIF(concat_ws(' / ',
          NULLIF(source.value->>'color', ''), NULLIF(source.value->>'size', '')
        ), ''),
        source.value->>'sku'
      )
   OR target.brand_name_snapshot IS DISTINCT FROM source.value->>'brand'
   OR target.image_url_snapshot IS DISTINCT FROM NULLIF(source.value->>'image', '')
   OR target.unit_price_snapshot IS DISTINCT FROM (source.value->>'price')::NUMERIC
   OR target.quantity IS DISTINCT FROM (source.value->>'quantity')::INTEGER;

WITH target_history AS (
  SELECT history.*,
         row_number() OVER (
           PARTITION BY history.order_id ORDER BY history.id
         )::INTEGER AS ordinal
  FROM order_status_history history
), source_history AS (
  SELECT source.id AS order_id, event.ordinality::INTEGER AS ordinal,
         event.value
  FROM migration.p4_order_source source
  CROSS JOIN LATERAL jsonb_array_elements(source.payload->'history')
    WITH ORDINALITY event(value, ordinality)
)
INSERT INTO p4_compatibility_issues
SELECT 'order_history_dto', source.order_id || ':' || source.ordinal,
       'structured order status event differs from source history action'
FROM source_history source
LEFT JOIN migration.p4_action_map mapping
  ON mapping.domain = 'order'
 AND mapping.legacy_action = source.value->>'action'
LEFT JOIN target_history target
  ON target.order_id = source.order_id AND target.ordinal = source.ordinal
WHERE mapping.legacy_action IS NULL OR target.id IS NULL
   OR target.status IS DISTINCT FROM mapping.status
   OR target.occurred_at IS DISTINCT FROM
        ((source.value->>'time') || '+08:00')::TIMESTAMPTZ;

INSERT INTO p4_compatibility_issues
SELECT 'coupon_dto', source.code,
       'normalized coupon or display-name fallback differs from source DTO'
FROM migration.p4_coupon_source source
LEFT JOIN coupons target ON target.code = source.code
WHERE target.id IS NULL OR target.name IS DISTINCT FROM source.code
   OR target.discount_type IS DISTINCT FROM source.payload->>'type'
   OR target.discount_value IS DISTINCT FROM (source.payload->>'discount')::NUMERIC
   OR target.minimum_amount IS DISTINCT FROM (source.payload->>'minOrder')::NUMERIC
   OR target.issue_quantity IS DISTINCT FROM (source.payload->>'quantity')::INTEGER
   OR target.status IS DISTINCT FROM source.payload->>'status'
   OR target.category IS DISTINCT FROM source.payload->>'category'
   OR target.valid_from IS DISTINCT FROM
        ((source.payload->>'startDate') || '+08:00')::TIMESTAMPTZ
   OR target.valid_until IS DISTINCT FROM
        ((source.payload->>'endDate') || '+08:00')::TIMESTAMPTZ;

INSERT INTO p4_compatibility_issues
SELECT 'booking_dto', source.id,
       'normalized booking scalar/snapshot fields differ from source DTO'
FROM migration.p4_booking_source source
LEFT JOIN bookings target ON target.id = source.id
WHERE target.id IS NULL
   OR target.customer_id IS DISTINCT FROM source.payload->>'customerId'
   OR target.campground_id IS DISTINCT FROM
        source.payload->'bookingInfo'->>'campgroundId'
   OR target.campground_name_snapshot IS DISTINCT FROM
        source.payload->'bookingInfo'->>'campgroundName'
   OR target.region_snapshot IS DISTINCT FROM
        source.payload->'bookingInfo'->>'region'
   OR target.check_in IS DISTINCT FROM
        (source.payload->'bookingInfo'->>'checkIn')::DATE
   OR target.check_out IS DISTINCT FROM
        (source.payload->'bookingInfo'->>'checkOut')::DATE
   OR target.guest_count IS DISTINCT FROM
        (source.payload->'bookingInfo'->>'guestCount')::INTEGER
   OR target.status IS DISTINCT FROM source.payload->>'status'
   OR target.created_at IS DISTINCT FROM
        ((source.payload->>'submittedAt') || '+08:00')::TIMESTAMPTZ;

INSERT INTO p4_compatibility_issues
SELECT 'booking_day_evidence', source.id,
       'original and resolved day counts are not fully represented in evidence'
FROM migration.p4_booking_source source
LEFT JOIN migration.p4_booking_day_count_resolution evidence
  ON evidence.booking_id = source.id
LEFT JOIN bookings target ON target.id = source.id
WHERE evidence.booking_id IS NULL OR target.id IS NULL
   OR evidence.source_weekday_count IS DISTINCT FROM
        (source.payload->'bookingInfo'->>'weekdayCount')::INTEGER
   OR evidence.source_holiday_count IS DISTINCT FROM
        (source.payload->'bookingInfo'->>'holidayCount')::INTEGER
   OR evidence.resolved_weekday_count IS DISTINCT FROM target.weekday_count
   OR evidence.resolved_holiday_count IS DISTINCT FROM target.holiday_count;

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
INSERT INTO p4_compatibility_issues
SELECT 'booking_zone_dto', source.booking_id || ':' || source.ordinal,
       'normalized selected-zone snapshot differs from source DTO'
FROM source_zones source
LEFT JOIN target_zones target
  ON target.booking_id = source.booking_id AND target.ordinal = source.ordinal
WHERE target.id IS NULL
   OR target.zone_id IS DISTINCT FROM source.value->>'zoneId'
   OR target.zone_type_snapshot IS DISTINCT FROM source.value->>'zoneType'
   OR target.quantity IS DISTINCT FROM (source.value->>'quantity')::INTEGER;

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
INSERT INTO p4_compatibility_issues
SELECT 'booking_rental_dto', source.booking_id || ':' || source.ordinal,
       'normalized selected-rental identity/snapshot differs from source DTO'
FROM source_rentals source
LEFT JOIN target_rentals target
  ON target.booking_id = source.booking_id AND target.ordinal = source.ordinal
WHERE target.id IS NULL
   OR target.rental_listing_id IS DISTINCT FROM source.value->>'equipmentId'
   OR target.rental_sku_variant_id IS DISTINCT FROM source.value->>'variantId'
   OR target.sku_snapshot IS DISTINCT FROM source.value->>'sku'
   OR target.name_snapshot IS DISTINCT FROM source.value->>'name'
   OR target.specification_snapshot IS DISTINCT FROM
        COALESCE(NULLIF(source.value->>'specLabel', ''), source.value->>'sku')
   OR target.quantity IS DISTINCT FROM (source.value->>'quantity')::INTEGER;

WITH target_history AS (
  SELECT history.*,
         row_number() OVER (
           PARTITION BY history.booking_id ORDER BY history.id
         )::INTEGER AS ordinal
  FROM booking_status_history history
), source_history AS (
  SELECT source.id AS booking_id, event.ordinality::INTEGER AS ordinal,
         event.value
  FROM migration.p4_booking_source source
  CROSS JOIN LATERAL jsonb_array_elements(source.payload->'history')
    WITH ORDINALITY event(value, ordinality)
)
INSERT INTO p4_compatibility_issues
SELECT 'booking_history_dto', source.booking_id || ':' || source.ordinal,
       'structured booking event differs from source history action'
FROM source_history source
LEFT JOIN migration.p4_action_map mapping
  ON mapping.domain = 'booking'
 AND mapping.legacy_action = source.value->>'action'
LEFT JOIN target_history target
  ON target.booking_id = source.booking_id AND target.ordinal = source.ordinal
WHERE mapping.legacy_action IS NULL OR target.id IS NULL
   OR target.status IS DISTINCT FROM mapping.status
   OR target.note IS DISTINCT FROM CASE
        WHEN mapping.note_pattern = 'cancel_reason'
        THEN substring(source.value->>'action' FROM '^已取消（原因：(.+)）$')
        ELSE NULL
      END
   OR target.occurred_at IS DISTINCT FROM
        ((source.value->>'time') || '+08:00')::TIMESTAMPTZ;

WITH selected AS (
  SELECT detail.*,
         row_number() OVER (
           PARTITION BY detail.booking_id ORDER BY detail.id
         )::INTEGER AS ordinal
  FROM booking_selected_rentals detail
)
INSERT INTO p4_compatibility_issues
SELECT 'reservation_dto', reservation.id::TEXT,
       'reservation identity, dates, lifecycle or idempotency differs from source booking'
FROM rental_stock_reservations reservation
JOIN selected detail ON detail.id = reservation.booking_selected_rental_id
JOIN migration.p4_booking_source source ON source.id = detail.booking_id
JOIN LATERAL (
  SELECT value
  FROM jsonb_array_elements(source.payload->'selectedRentals')
    WITH ORDINALITY rental(value, ordinality)
  WHERE ordinality = detail.ordinal
) rental ON TRUE
WHERE reservation.rental_sku_variant_id IS DISTINCT FROM rental.value->>'variantId'
   OR reservation.location_id IS DISTINCT FROM
        source.payload->'bookingInfo'->>'campgroundId'
   OR reservation.check_in IS DISTINCT FROM
        (source.payload->'bookingInfo'->>'checkIn')::DATE
   OR reservation.check_out IS DISTINCT FROM
        (source.payload->'bookingInfo'->>'checkOut')::DATE
   OR reservation.quantity IS DISTINCT FROM (rental.value->>'quantity')::INTEGER
   OR reservation.status IS DISTINCT FROM CASE source.payload->>'status'
        WHEN 'completed' THEN 'fulfilled'
        WHEN 'cancelled' THEN 'released'
        ELSE 'active'
      END
   OR reservation.idempotency_key IS DISTINCT FROM
        'legacy-booking-' || source.id || '-rental-' || detail.ordinal;

INSERT INTO p4_compatibility_issues
SELECT 'snapshot_fallback', source_id || ':' || field_name,
       'unapproved fallback field or fallback authority'
FROM migration.p4_snapshot_fallbacks
WHERE NOT (
  (domain = 'order' AND field_name = 'buyer_email_snapshot'
    AND fallback_source = 'customers.email')
  OR (domain = 'order' AND field_name = 'recipient_name_snapshot'
    AND fallback_source = 'orders.buyerName')
  OR (domain = 'order' AND field_name = 'shipping_phone_snapshot'
    AND fallback_source = 'customers.phone')
  OR (domain = 'coupon' AND field_name = 'name'
    AND fallback_source = 'coupons.code')
);

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', COALESCE(jsonb_agg(jsonb_build_object(
    'check', check_name, 'id', data_id, 'reason', reason
  ) ORDER BY check_name, data_id), '[]'::JSONB)
))
FROM p4_compatibility_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p4_compatibility_issues) THEN
    RAISE EXCEPTION 'P4 compatibility validation failed with % issue(s)',
      (SELECT count(*) FROM p4_compatibility_issues);
  END IF;
END $$;
