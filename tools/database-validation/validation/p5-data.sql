\set ON_ERROR_STOP on

CREATE TEMP TABLE p5_data_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

DO $$
BEGIN
  IF to_regclass('migration.movement_migration_map') IS NOT NULL THEN
    EXECUTE 'CREATE TEMP VIEW p5_validation_movement_map AS SELECT * FROM migration.movement_migration_map';
  ELSE
    EXECUTE 'CREATE TEMP VIEW p5_validation_movement_map AS SELECT * FROM public.movement_migration_map';
  END IF;
END $$;

INSERT INTO p5_data_issues
SELECT 'source_count', expected.name,
       format('expected %s, found %s', expected.expected_count, actual.actual_count)
FROM (VALUES
  ('policy', 1::bigint), ('blocks', 2), ('closures', 2),
  ('movement_headers', 100), ('movement_items', 141)
) expected(name, expected_count)
JOIN LATERAL (
  SELECT CASE expected.name
    WHEN 'policy' THEN (SELECT count(*) FROM migration.p5_policy_source)
    WHEN 'blocks' THEN (SELECT count(*) FROM migration.p5_zone_block_source)
    WHEN 'closures' THEN (SELECT count(*) FROM migration.p5_closure_source)
    WHEN 'movement_headers' THEN (SELECT count(*) FROM migration.p5_movement_source)
    WHEN 'movement_items' THEN (
      SELECT sum(jsonb_array_length(payload->'items')) FROM migration.p5_movement_source
    ) END::bigint AS actual_count
) actual ON TRUE
WHERE actual.actual_count <> expected.expected_count;

INSERT INTO p5_data_issues
SELECT 'policy_value', 'booking_policies', 'normalized policy differs from frozen source'
WHERE NOT EXISTS (
  SELECT 1
  FROM booking_policies policy
  JOIN migration.p5_policy_source source ON source.id = policy.id
  WHERE policy.id = 1
    AND policy.booking_window_days = (source.payload->>'bookingWindowDays')::integer
    AND policy.advance_days = (source.payload->>'minLeadDays')::integer
    AND policy.max_nights = (source.payload->>'maxStayNights')::integer
    AND policy.timezone = source.payload->>'timezone'
    AND policy.low_availability_threshold =
        round((source.payload#>>'{availabilityStatus,lowThresholdRatio}')::numeric * 100)
);

INSERT INTO p5_data_issues
SELECT 'target_count', expected.name,
       format('expected %s, found %s', expected.expected_count, actual.actual_count)
FROM (VALUES
  ('store_minimums', 156::bigint), ('rental_minimums', 333),
  ('new_movement_headers', 171), ('store_items', 65), ('rental_items', 44),
  ('conversions', 31), ('movement_map', 141), ('approved_quarantine', 1)
) expected(name, expected_count)
JOIN LATERAL (
  SELECT CASE expected.name
    WHEN 'store_minimums' THEN (SELECT count(*) FROM product_variant_min_stocks)
    WHEN 'rental_minimums' THEN (SELECT count(*) FROM rental_sku_variant_min_stocks)
    WHEN 'new_movement_headers' THEN (SELECT count(*) FROM inventory_movements)
    WHEN 'store_items' THEN (SELECT count(*) FROM store_inventory_movement_items)
    WHEN 'rental_items' THEN (SELECT count(*) FROM rental_inventory_movement_items)
    WHEN 'conversions' THEN (SELECT count(*) FROM inventory_conversions)
    WHEN 'movement_map' THEN (SELECT count(*) FROM p5_validation_movement_map)
    WHEN 'approved_quarantine' THEN (
      SELECT count(*) FROM p5_validation_movement_map WHERE quarantine_reason IS NOT NULL
    ) END::bigint AS actual_count
) actual ON TRUE
WHERE actual.actual_count <> expected.expected_count;

INSERT INTO p5_data_issues
SELECT 'movement_map', source.legacy_movement_id || ':' || (item.ordinal - 1),
       'legacy item has no exactly-one migration disposition'
FROM migration.p5_movement_source source
CROSS JOIN LATERAL jsonb_array_elements(source.payload->'items')
  WITH ORDINALITY item(payload, ordinal)
LEFT JOIN p5_validation_movement_map mapping
  ON mapping.legacy_movement_id = source.legacy_movement_id
 AND mapping.legacy_item_ordinal = item.ordinal - 1
WHERE mapping.legacy_movement_id IS NULL
   OR num_nonnulls(
     mapping.store_item_id, mapping.rental_item_id,
     mapping.conversion_id, mapping.quarantine_reason
   ) <> 1;

WITH classifications AS (
  SELECT legacy_movement_id,
         CASE WHEN store_item_id IS NOT NULL THEN 'store'
              WHEN rental_item_id IS NOT NULL THEN 'rental'
              WHEN conversion_id IS NOT NULL THEN 'conversion'
              ELSE 'quarantine' END AS classification
  FROM p5_validation_movement_map
), split_headers AS (
  SELECT legacy_movement_id
  FROM classifications
  GROUP BY legacy_movement_id
  HAVING count(DISTINCT classification) > 1
)
INSERT INTO p5_data_issues
SELECT 'split_legacy_headers', 'movement_migration_map',
       format('expected at least 23 split headers, found %s', count(*))
FROM split_headers
HAVING count(*) < 23;

WITH source_items AS (
  SELECT source.legacy_movement_id, item.ordinal - 1 AS ordinal,
         item.payload,
         source_location.inventory_domain AS source_domain,
         destination_location.inventory_domain AS destination_domain
  FROM migration.p5_movement_source source
  CROSS JOIN LATERAL jsonb_array_elements(source.payload->'items')
    WITH ORDINALITY item(payload, ordinal)
  LEFT JOIN migration.p5_location_resolution source_location
    ON source_location.legacy_label = item.payload->>'fromStore'
  LEFT JOIN migration.p5_location_resolution destination_location
    ON destination_location.legacy_label = item.payload->>'toStore'
), cross_domain AS (
  SELECT source_item.*, mapping.conversion_id, mapping.quarantine_reason
  FROM source_items source_item
  JOIN p5_validation_movement_map mapping
    ON mapping.legacy_movement_id = source_item.legacy_movement_id
   AND mapping.legacy_item_ordinal = source_item.ordinal
  WHERE source_domain = 'store' AND destination_domain = 'rental'
)
INSERT INTO p5_data_issues
SELECT 'store_to_camp_classification', 'movement_migration_map',
       format('expected 32 classified rows (31 conversion + 1 quarantine), found %s/%s/%s',
              count(*), count(conversion_id), count(quarantine_reason))
FROM cross_domain
HAVING count(*) <> 32 OR count(conversion_id) <> 31 OR count(quarantine_reason) <> 1;

INSERT INTO p5_data_issues
SELECT 'unresolved_location', quarantine.source_row_id,
       'P1 quarantined label still lacks a deterministic P5 alias'
FROM migration.p1_location_quarantine quarantine
LEFT JOIN migration.p1_location_aliases alias ON alias.alias = quarantine.raw_value
WHERE alias.alias IS NULL;

INSERT INTO p5_data_issues
SELECT 'guessed_variant', legacy_movement_id || ':' || legacy_item_ordinal,
       'variant was not resolved by exact product and variant label'
FROM migration.p5_variant_resolution
WHERE resolution_method <> 'EXACT_PRODUCT_AND_VARIANT_LABEL'
   OR disposition_status NOT IN ('RESOLVED', 'APPROVED_QUARANTINE_NO_RENTAL_VARIANT');

INSERT INTO p5_data_issues
SELECT 'minimum_location_domain', variant_id || '/' || minimum.location_id,
       'store minimum points to a non-store location'
FROM product_variant_min_stocks minimum
JOIN inventory_locations location ON location.id = minimum.location_id
WHERE location.inventory_domain <> 'store'
UNION ALL
SELECT 'minimum_location_domain', rental_sku_variant_id || '/' || minimum.location_id,
       'rental minimum points to a non-rental location'
FROM rental_sku_variant_min_stocks minimum
JOIN inventory_locations location ON location.id = minimum.location_id
WHERE location.inventory_domain <> 'rental';

INSERT INTO p5_data_issues
SELECT 'movement_location_domain', movement.id::text,
       'movement location domain differs from its header domain'
FROM inventory_movements movement
LEFT JOIN inventory_locations source ON source.id = movement.source_location_id
LEFT JOIN inventory_locations destination ON destination.id = movement.destination_location_id
WHERE (source.id IS NOT NULL AND source.inventory_domain <> movement.inventory_domain)
   OR (destination.id IS NOT NULL AND destination.inventory_domain <> movement.inventory_domain);

INSERT INTO p5_data_issues
SELECT 'conversion_domain', conversion.id::text,
       'conversion is not store movement/location to rental movement/location'
FROM inventory_conversions conversion
JOIN inventory_movements source_movement ON source_movement.id = conversion.source_movement_id
JOIN inventory_movements destination_movement
  ON destination_movement.id = conversion.destination_movement_id
JOIN inventory_locations source_location ON source_location.id = conversion.source_location_id
JOIN inventory_locations destination_location
  ON destination_location.id = conversion.destination_location_id
WHERE source_movement.inventory_domain <> 'store'
   OR destination_movement.inventory_domain <> 'rental'
   OR source_location.inventory_domain <> 'store'
   OR destination_location.inventory_domain <> 'rental';

INSERT INTO p5_data_issues
SELECT 'negative_physical_stock', variant_id || '/' || location_id,
       'store physical stock is negative'
FROM inventory_stocks WHERE on_hand_quantity < 0
UNION ALL
SELECT 'negative_physical_stock', rental_sku_variant_id || '/' || location_id,
       'rental physical stock is negative'
FROM rental_sku_variant_stocks WHERE on_hand_quantity < 0;

INSERT INTO p5_data_issues
SELECT 'negative_availability', zone_id || '/' || stay_date,
       'zone availability is negative'
FROM get_zone_availability('2026-01-01', '2026-12-31', NULL, NULL)
WHERE available_quantity < 0;

INSERT INTO p5_data_issues
SELECT 'reservation_domain', id::text, 'product reservation is not in store domain'
FROM product_stock_reservations WHERE inventory_domain <> 'store'
UNION ALL
SELECT 'reservation_domain', id::text, 'rental reservation is not in rental domain'
FROM rental_stock_reservations WHERE inventory_domain <> 'rental';

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', coalesce(jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name), '[]'::jsonb)
))
FROM p5_data_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p5_data_issues) THEN
    RAISE EXCEPTION 'P5 data validation failed with % issue(s)',
      (SELECT count(*) FROM p5_data_issues);
  END IF;
END $$;
