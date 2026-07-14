\set ON_ERROR_STOP on

CREATE TEMP TABLE p5_compatibility_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

CREATE TEMP VIEW p5_validation_booking_policy_compatibility AS
SELECT jsonb_build_object(
  'bookingWindowDays', policy.booking_window_days,
  'minLeadDays', policy.advance_days,
  'maxStayNights', policy.max_nights,
  'timezone', policy.timezone,
  'occupyingStatuses', (
    SELECT jsonb_agg(status ORDER BY CASE status
      WHEN 'pending' THEN 1 WHEN 'confirmed' THEN 2 WHEN 'completed' THEN 3 ELSE 99 END)
    FROM booking_policy_occupying_statuses WHERE policy_id = policy.id
  ),
  'dateRule', jsonb_build_object('checkInInclusive', TRUE, 'checkOutExclusive', TRUE),
  'availabilityStatus', jsonb_build_object(
    'lowThresholdRatio', policy.low_availability_threshold / 100.0
  )
) AS policy
FROM booking_policies policy;

CREATE TEMP VIEW p5_validation_zone_blocks_compatibility AS
SELECT legacy_block_id AS id, campground_id AS "campgroundId", zone_id AS "zoneId",
       start_date AS "startDate", end_date AS "endDate",
       blocked_quantity AS "blockedSites", reason,
       created_by AS "createdBy", created_at AS "createdAt"
FROM zone_blocks;

CREATE TEMP VIEW p5_validation_closures_compatibility AS
SELECT legacy_closure_id AS id, campground_id AS "campgroundId",
       closure_type AS type, start_date AS "startDate", end_date AS "endDate",
       weekday AS "dayOfWeek", effective_from AS "effectiveFrom",
       effective_to AS "effectiveTo", reason,
       created_by AS "createdBy", created_at AS "createdAt"
FROM campground_closures;

DO $$
BEGIN
  IF to_regclass('migration.movement_migration_map') IS NOT NULL THEN
    EXECUTE 'CREATE TEMP VIEW p5_validation_movement_map AS SELECT * FROM migration.movement_migration_map';
  ELSE
    EXECUTE 'CREATE TEMP VIEW p5_validation_movement_map AS SELECT * FROM public.movement_migration_map';
  END IF;
END $$;

INSERT INTO p5_compatibility_issues
SELECT 'policy_dto', 'booking_policy_compatibility',
       'compatibility JSON differs from booking-policy.json'
FROM p5_validation_booking_policy_compatibility compatibility
CROSS JOIN migration.p5_policy_source source
WHERE compatibility.policy <> source.payload;

INSERT INTO p5_compatibility_issues
SELECT 'zone_block_dto', source.legacy_id, 'normalized block differs from source DTO'
FROM migration.p5_zone_block_source source
LEFT JOIN p5_validation_zone_blocks_compatibility target ON target.id = source.legacy_id
WHERE target.id IS NULL
   OR target."campgroundId" <> source.payload->>'campgroundId'
   OR target."zoneId" <> source.payload->>'zoneId'
   OR target."startDate" <> (source.payload->>'startDate')::date
   OR target."endDate" <> (source.payload->>'endDate')::date
   OR target."blockedSites" <> (source.payload->>'blockedSites')::integer
   OR target.reason <> source.payload->>'reason'
   OR target."createdBy" <> source.payload->>'createdBy';

INSERT INTO p5_compatibility_issues
SELECT 'closure_dto', source.legacy_id, 'normalized closure differs from source DTO'
FROM migration.p5_closure_source source
LEFT JOIN p5_validation_closures_compatibility target ON target.id = source.legacy_id
WHERE target.id IS NULL
   OR target."campgroundId" <> source.payload->>'campgroundId'
   OR target.type <> source.payload->>'type'
   OR target."startDate" IS DISTINCT FROM (source.payload->>'startDate')::date
   OR target."endDate" IS DISTINCT FROM (source.payload->>'endDate')::date
   OR target."dayOfWeek" IS DISTINCT FROM (source.payload->>'dayOfWeek')::smallint
   OR target."effectiveFrom" IS DISTINCT FROM (source.payload->>'effectiveFrom')::date
   OR target."effectiveTo" IS DISTINCT FROM (source.payload->>'effectiveTo')::date
   OR target.reason <> source.payload->>'reason'
   OR target."createdBy" <> source.payload->>'createdBy';

WITH source_items AS (
  SELECT source.legacy_movement_id, item.ordinal - 1 AS ordinal, item.payload,
         source_location.location_id AS source_location_id,
         destination_location.location_id AS destination_location_id
  FROM migration.p5_movement_source source
  CROSS JOIN LATERAL jsonb_array_elements(source.payload->'items')
    WITH ORDINALITY item(payload, ordinal)
  LEFT JOIN migration.p5_location_resolution source_location
    ON source_location.legacy_label = item.payload->>'fromStore'
  LEFT JOIN migration.p5_location_resolution destination_location
    ON destination_location.legacy_label = item.payload->>'toStore'
), resolved AS (
  SELECT source_item.*, resolution.product_variant_id,
         mapping.store_item_id, mapping.rental_item_id,
         mapping.conversion_id, mapping.quarantine_reason
  FROM source_items source_item
  JOIN migration.p5_variant_resolution resolution
    ON resolution.legacy_movement_id = source_item.legacy_movement_id
   AND resolution.legacy_item_ordinal = source_item.ordinal
  JOIN p5_validation_movement_map mapping
    ON mapping.legacy_movement_id = source_item.legacy_movement_id
   AND mapping.legacy_item_ordinal = source_item.ordinal
)
INSERT INTO p5_compatibility_issues
SELECT 'movement_item_dto', resolved.legacy_movement_id || ':' || resolved.ordinal,
       'new concrete item/conversion does not reproduce source identity, snapshot or quantity'
FROM resolved
LEFT JOIN store_inventory_movement_items store_item ON store_item.id = resolved.store_item_id
LEFT JOIN rental_inventory_movement_items rental_item ON rental_item.id = resolved.rental_item_id
LEFT JOIN inventory_conversions conversion ON conversion.id = resolved.conversion_id
WHERE (resolved.store_item_id IS NOT NULL AND (
         store_item.variant_id IS DISTINCT FROM resolved.product_variant_id
         OR store_item.item_name_snapshot IS DISTINCT FROM resolved.payload->>'productName'
         OR store_item.quantity IS DISTINCT FROM (resolved.payload->>'quantity')::integer
       ))
   OR (resolved.rental_item_id IS NOT NULL AND (
         rental_item.rental_sku_variant_id IS DISTINCT FROM resolved.product_variant_id
         OR rental_item.item_name_snapshot IS DISTINCT FROM resolved.payload->>'productName'
         OR rental_item.quantity IS DISTINCT FROM (resolved.payload->>'quantity')::integer
       ))
   OR (resolved.conversion_id IS NOT NULL AND (
         conversion.source_variant_id IS DISTINCT FROM resolved.product_variant_id
         OR conversion.destination_rental_variant_id IS DISTINCT FROM resolved.product_variant_id
         OR conversion.source_location_id IS DISTINCT FROM resolved.source_location_id
         OR conversion.destination_location_id IS DISTINCT FROM resolved.destination_location_id
         OR conversion.quantity IS DISTINCT FROM (resolved.payload->>'quantity')::integer
       ))
   OR (resolved.quarantine_reason IS NOT NULL AND NOT (
         resolved.legacy_movement_id = '97' AND resolved.ordinal = 0
         AND resolved.quarantine_reason LIKE 'NO_RENTAL_VARIANT:%'
       ));

WITH expected AS (
  SELECT item.id, item.movement_id, item.inventory_domain, item.variant_id,
         item.sku_snapshot, item.item_name_snapshot, item.quantity
  FROM store_inventory_movement_items item
  UNION ALL
  SELECT item.id, item.movement_id, item.inventory_domain,
         item.rental_sku_variant_id, item.sku_snapshot,
         item.item_name_snapshot, item.quantity
  FROM rental_inventory_movement_items item
), difference AS (
  (SELECT * FROM inventory_movement_items_view EXCEPT ALL SELECT * FROM expected)
  UNION ALL
  (SELECT * FROM expected EXCEPT ALL SELECT * FROM inventory_movement_items_view)
)
INSERT INTO p5_compatibility_issues
SELECT 'movement_items_view', 'inventory_movement_items_view',
       'view differs from the UNION ALL concrete-table contract'
WHERE EXISTS (SELECT 1 FROM difference);

INSERT INTO p5_compatibility_issues
SELECT 'legacy_header_trace', legacy_movement_id, 'legacy movement has no new header trace'
FROM migration.p5_movement_source source
WHERE NOT EXISTS (
  SELECT 1 FROM inventory_movements movement
  WHERE movement.legacy_movement_id = source.legacy_movement_id
)
AND NOT EXISTS (
  SELECT 1 FROM p5_validation_movement_map mapping
  WHERE mapping.legacy_movement_id = source.legacy_movement_id
    AND mapping.quarantine_reason IS NOT NULL
);

-- Independent source-JSON occupancy calculation using the same public DTO
-- interval contract as booking-availability.js.
WITH expected AS (
  SELECT selected.value->>'zoneId' AS zone_id,
         day_value::date AS stay_date,
         sum((selected.value->>'quantity')::integer)::bigint AS booked_quantity
  FROM migration.p4_booking_source source
  CROSS JOIN LATERAL jsonb_array_elements(source.payload->'selectedZones') selected(value)
  CROSS JOIN LATERAL generate_series(
    (source.payload#>>'{bookingInfo,checkIn}')::date,
    (source.payload#>>'{bookingInfo,checkOut}')::date - 1,
    interval '1 day'
  ) day_value
  WHERE source.payload->>'status' IN ('pending', 'confirmed', 'completed')
  GROUP BY selected.value->>'zoneId', day_value::date
), actual AS (
  SELECT zone_id, stay_date, booked_quantity, is_closed
  FROM get_zone_availability('2026-01-01', '2026-12-31', NULL, NULL)
)
INSERT INTO p5_compatibility_issues
SELECT 'booking_interval', coalesce(expected.zone_id, actual.zone_id) || '/'
       || coalesce(expected.stay_date, actual.stay_date),
       format('source/SQL occupied mismatch: %s/%s',
              CASE WHEN actual.is_closed THEN 0 ELSE coalesce(expected.booked_quantity, 0) END,
              coalesce(actual.booked_quantity, 0))
FROM expected
FULL JOIN actual USING (zone_id, stay_date)
WHERE CASE WHEN actual.is_closed THEN 0 ELSE coalesce(expected.booked_quantity, 0) END
      <> coalesce(actual.booked_quantity, 0);

INSERT INTO p5_compatibility_issues
SELECT 'availability_golden', golden.case_name,
       format('expected available/closed %s/%s, found %s/%s',
              golden.available_quantity, golden.is_closed,
              actual.available_quantity, actual.is_closed)
FROM (VALUES
  ('block_start', 'Z001'::varchar, '2026-07-20'::date, 8::bigint, false),
  ('block_end_exclusive', 'Z001', '2026-07-23', 10, false),
  ('date_closure_start', 'Z001', '2026-07-28', 0, true),
  ('date_closure_end_exclusive', 'Z001', '2026-07-29', 10, false),
  ('weekly_effective', 'Z003', '2026-07-14', 0, true),
  ('weekly_before_effective', 'Z003', '2026-07-07', 15, false)
) golden(case_name, zone_id, stay_date, available_quantity, is_closed)
LEFT JOIN LATERAL get_zone_availability(
  golden.stay_date, golden.stay_date, NULL, golden.zone_id
) actual ON TRUE
WHERE actual.zone_id IS NULL
   OR actual.available_quantity <> golden.available_quantity
   OR actual.is_closed <> golden.is_closed;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', coalesce(jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name), '[]'::jsonb)
))
FROM p5_compatibility_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p5_compatibility_issues) THEN
    RAISE EXCEPTION 'P5 compatibility validation failed with % issue(s)',
      (SELECT count(*) FROM p5_compatibility_issues);
  END IF;
END $$;
