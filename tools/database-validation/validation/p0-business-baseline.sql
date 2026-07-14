\set ON_ERROR_STOP on
\pset tuples_only on
\pset format unaligned

-- P0 intentionally records legacy discrepancies. Every row carries an ID,
-- field, reason and disposition state instead of silently dropping a mismatch.
WITH issues AS (
  SELECT 'order'::text AS domain, o.id::text AS data_id, 'subtotal'::text AS field,
         format('stored=%s calculated=%s', o.subtotal, COALESCE(x.calculated, 0)) AS reason,
         'PENDING_P4'::text AS disposition_status
  FROM orders o
  LEFT JOIN (
    SELECT order_id, sum(price * quantity) AS calculated FROM order_items GROUP BY order_id
  ) x ON x.order_id = o.id
  WHERE o.subtotal <> COALESCE(x.calculated, 0)

  UNION ALL
  SELECT 'order', o.id::text, 'total',
         format('stored=%s calculated=%s', o.total, o.subtotal + o.shipping_fee - o.discount),
         'PENDING_P4'
  FROM orders o
  WHERE o.total <> o.subtotal + o.shipping_fee - o.discount

  UNION ALL
  SELECT 'booking', b.id::text, 'zone_total',
         format('stored=%s calculated=%s', b.zone_total, COALESCE(x.calculated, 0)),
         'PENDING_P4'
  FROM bookings b
  LEFT JOIN (
    SELECT booking_id, sum(subtotal) AS calculated FROM booking_selected_zones GROUP BY booking_id
  ) x ON x.booking_id = b.id
  WHERE b.zone_total <> COALESCE(x.calculated, 0)

  UNION ALL
  SELECT 'booking', b.id::text, 'rental_total',
         format('stored=%s calculated=%s', b.rental_total, COALESCE(x.calculated, 0)),
         'PENDING_P4'
  FROM bookings b
  LEFT JOIN (
    SELECT booking_id, sum(subtotal) AS calculated FROM booking_selected_rentals GROUP BY booking_id
  ) x ON x.booking_id = b.id
  WHERE b.rental_total <> COALESCE(x.calculated, 0)

  UNION ALL
  SELECT 'booking', b.id::text, 'final_amount',
         format('stored=%s calculated=%s', b.final_amount, b.zone_total + b.rental_total - b.applied_discount),
         'PENDING_P4'
  FROM bookings b
  WHERE b.final_amount <> b.zone_total + b.rental_total - b.applied_discount

  UNION ALL
  SELECT 'inventory', s.id::text, 'quantity', format('negative rental stock=%s', s.quantity), 'PENDING_P3'
  FROM rental_sku_variant_stocks s
  WHERE s.quantity < 0

  UNION ALL
  SELECT 'reference', l.id, 'campground_id', format('unknown campground=%s', l.campground_id), 'PENDING_P3'
  FROM rental_listings l
  LEFT JOIN campgrounds c ON c.id = l.campground_id
  WHERE c.id IS NULL

  UNION ALL
  SELECT 'location-map', location_id, 'location_id',
         CASE WHEN location_id = 'C001' THEN 'rental warehouse; no campground row expected'
              WHEN c.id IS NOT NULL THEN 'bookable campground mapping exists'
              ELSE 'location has no campground mapping' END,
         CASE WHEN location_id BETWEEN 'C001' AND 'C009' THEN 'DOCUMENTED' ELSE 'PENDING_P1' END
  FROM (
    SELECT DISTINCT campground_id AS location_id FROM rental_sku_variant_stocks
  ) locations
  LEFT JOIN campgrounds c ON c.id = locations.location_id
)
SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*) FILTER (WHERE disposition_status LIKE 'PENDING%'),
  'rows', COALESCE(jsonb_agg(jsonb_build_object(
    'domain', domain,
    'id', data_id,
    'field', field,
    'reason', reason,
    'dispositionStatus', disposition_status
  ) ORDER BY domain, data_id, field), '[]'::jsonb)
))
FROM issues;
