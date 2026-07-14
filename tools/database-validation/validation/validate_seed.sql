\set ON_ERROR_STOP on

-- Phase validators are intentionally reused so P7 cannot hide a regression
-- behind a new aggregate count.
\ir p1-data.sql
\ir p2-data.sql
\ir p3-data.sql
\ir p4-data.sql
\ir p5-data.sql
\ir p6-data.sql

CREATE TEMP TABLE p7_seed_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

DO $$
BEGIN
  IF to_regclass('migration.movement_migration_map') IS NOT NULL THEN
    EXECUTE 'CREATE TEMP VIEW p7_validation_movement_map AS SELECT * FROM migration.movement_migration_map';
  ELSE
    EXECUTE 'CREATE TEMP VIEW p7_validation_movement_map AS SELECT * FROM public.movement_migration_map';
  END IF;
END $$;

INSERT INTO p7_seed_issues
SELECT 'empty_business_key', 'customers.id', 'empty customer id'
FROM customers WHERE btrim(id) = ''
UNION ALL
SELECT 'empty_business_key', 'products.id', 'empty product id'
FROM products WHERE btrim(id) = ''
UNION ALL
SELECT 'empty_business_key', 'rental_skus.id', 'empty rental sku id'
FROM rental_skus WHERE btrim(id) = ''
UNION ALL
SELECT 'empty_business_key', 'campgrounds.id', 'empty campground id'
FROM campgrounds WHERE btrim(id) = ''
UNION ALL
SELECT 'empty_business_key', 'orders.id', 'empty order id'
FROM orders WHERE btrim(id) = ''
UNION ALL
SELECT 'empty_business_key', 'bookings.id', 'empty booking id'
FROM bookings WHERE btrim(id) = '';

INSERT INTO p7_seed_issues
SELECT 'unresolved_migration_evidence', legacy_movement_id || '#' || legacy_item_ordinal,
       'movement row does not have exactly one approved disposition'
FROM p7_validation_movement_map
WHERE num_nonnulls(store_item_id, rental_item_id, conversion_id, quarantine_reason) <> 1;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', coalesce(jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name), '[]'::jsonb)
)) FROM p7_seed_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p7_seed_issues) THEN
    RAISE EXCEPTION 'P7 seed validation failed with % issue(s)',
      (SELECT count(*) FROM p7_seed_issues);
  END IF;
END $$;
