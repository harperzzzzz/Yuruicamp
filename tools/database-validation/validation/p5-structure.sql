\set ON_ERROR_STOP on

CREATE TEMP TABLE p5_structure_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p5_structure_issues
SELECT 'required_relation', expected.name, 'missing or wrong P5 relation kind'
FROM (VALUES
  ('booking_policies', 'BASE TABLE'),
  ('booking_policy_occupying_statuses', 'BASE TABLE'),
  ('booking_policy_availability_statuses', 'BASE TABLE'),
  ('zone_blocks', 'BASE TABLE'), ('campground_closures', 'BASE TABLE'),
  ('product_variant_min_stocks', 'BASE TABLE'),
  ('rental_sku_variant_min_stocks', 'BASE TABLE'),
  ('inventory_movements', 'BASE TABLE'),
  ('store_inventory_movement_items', 'BASE TABLE'),
  ('rental_inventory_movement_items', 'BASE TABLE'),
  ('inventory_conversions', 'BASE TABLE'),
  ('movement_migration_map', 'BASE TABLE'),
  ('inventory_movement_items_view', 'VIEW'),
  ('booking_policy_compatibility', 'VIEW'),
  ('zone_blocks_compatibility', 'VIEW'),
  ('campground_closures_compatibility', 'VIEW')
) expected(name, kind)
LEFT JOIN information_schema.tables actual
  ON actual.table_schema = 'public' AND actual.table_name = expected.name
WHERE actual.table_name IS NULL OR actual.table_type <> expected.kind;

INSERT INTO p5_structure_issues
SELECT 'forbidden_relation', actual.relname,
       'shared physical inventory movement item relation must not exist'
FROM pg_class actual
JOIN pg_namespace namespace ON namespace.oid = actual.relnamespace
WHERE namespace.nspname = 'public'
  AND actual.relname = 'inventory_movement_items'
  AND actual.relkind IN ('r', 'p', 'v', 'm');

INSERT INTO p5_structure_issues
SELECT 'required_constraint', expected.name, 'missing or wrong P5 constraint type'
FROM (VALUES
  ('pk_booking_policies', 'p'), ('ck_booking_policies_singleton', 'c'),
  ('ck_booking_policies_ranges', 'c'), ('ck_booking_policies_timezone', 'c'),
  ('pk_booking_policy_occupying_statuses', 'p'),
  ('fk_booking_policy_occupying_statuses_policy_id', 'f'),
  ('pk_booking_policy_availability_statuses', 'p'),
  ('fk_booking_policy_availability_statuses_policy_id', 'f'),
  ('pk_zone_blocks', 'p'), ('fk_zone_blocks_campground_id_zone_id', 'f'),
  ('fk_zone_blocks_created_by', 'f'), ('ck_zone_blocks_dates', 'c'),
  ('ck_zone_blocks_quantity', 'c'), ('pk_campground_closures', 'p'),
  ('ck_campground_closures_payload', 'c'),
  ('pk_product_variant_min_stocks', 'p'),
  ('pk_rental_sku_variant_min_stocks', 'p'),
  ('pk_inventory_movements', 'p'), ('uq_inventory_movements_movement_no', 'u'),
  ('uq_inventory_movements_id_inventory_domain', 'u'),
  ('fk_inventory_movements_source_location_domain', 'f'),
  ('fk_inventory_movements_destination_location_domain', 'f'),
  ('ck_inventory_movements_domain', 'c'), ('ck_inventory_movements_status', 'c'),
  ('ck_inventory_movements_posting', 'c'),
  ('ck_inventory_movements_type_payload', 'c'),
  ('pk_store_inventory_movement_items', 'p'),
  ('fk_store_inventory_movement_items_movement_id_inventory_domain', 'f'),
  ('ck_store_inventory_movement_items_domain', 'c'),
  ('pk_rental_inventory_movement_items', 'p'),
  ('fk_rental_inventory_movement_items_movement_id_inventory_domain', 'f'),
  ('ck_rental_inventory_movement_items_domain', 'c'),
  ('pk_inventory_conversions', 'p'),
  ('uq_inventory_conversions_idempotency_key', 'u'),
  ('pk_movement_migration_map', 'p'),
  ('ck_movement_migration_map_exactly_one', 'c'),
  ('ck_product_stock_reservations_domain', 'c'),
  ('fk_product_stock_reservations_location_domain', 'f'),
  ('ck_rental_stock_reservations_domain', 'c'),
  ('fk_rental_stock_reservations_location_domain', 'f')
) expected(name, type)
LEFT JOIN pg_constraint actual
  ON actual.conname = LEFT(expected.name, 63)
 AND actual.contype::text = expected.type
WHERE actual.oid IS NULL;

WITH p5_tables AS (
  SELECT relation.oid
  FROM pg_class relation
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname IN (
      'booking_policy_occupying_statuses',
      'booking_policy_availability_statuses', 'zone_blocks',
      'campground_closures', 'product_variant_min_stocks',
      'rental_sku_variant_min_stocks', 'inventory_movements',
      'store_inventory_movement_items', 'rental_inventory_movement_items',
      'inventory_conversions', 'movement_migration_map',
      'product_stock_reservations', 'rental_stock_reservations'
    )
), foreign_keys AS (
  SELECT constraint_data.conname, constraint_data.conrelid, constraint_data.conkey
  FROM pg_constraint constraint_data
  JOIN p5_tables p5_table ON p5_table.oid = constraint_data.conrelid
  WHERE constraint_data.contype = 'f'
)
INSERT INTO p5_structure_issues
SELECT 'foreign_key_index', foreign_key.conname,
       'referencing columns lack a usable non-partial index'
FROM foreign_keys foreign_key
WHERE NOT EXISTS (
  SELECT 1 FROM pg_index index_data
  WHERE index_data.indrelid = foreign_key.conrelid
    AND index_data.indisvalid AND index_data.indpred IS NULL
    AND foreign_key.conkey <@ index_data.indkey::smallint[]
);

INSERT INTO p5_structure_issues
SELECT 'policy_jsonb', column_name, 'queryable policy JSONB remains in public table'
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'booking_policies'
  AND data_type = 'jsonb';

INSERT INTO p5_structure_issues
SELECT 'movement_domain_fk', constraint_data.conname,
       'movement location FK is not composite with inventory_domain'
FROM pg_constraint constraint_data
JOIN pg_class relation ON relation.oid = constraint_data.conrelid
WHERE relation.relname = 'inventory_movements'
  AND constraint_data.conname IN (
    'fk_inventory_movements_source_location_domain',
    'fk_inventory_movements_destination_location_domain'
  )
  AND cardinality(constraint_data.conkey) <> 2;

INSERT INTO p5_structure_issues
SELECT 'required_function', 'get_zone_availability',
       'parameterized zone availability function is missing'
WHERE to_regprocedure(
  'get_zone_availability(date,date,character varying,character varying)'
) IS NULL;

INSERT INTO p5_structure_issues
SELECT 'backend_owned_trigger', expected.name,
       'P5 lifecycle/domain validation must be implemented in Spring Boot'
FROM (VALUES
  ('trg_inventory_movements_immutable'),
  ('trg_store_inventory_movement_items_draft_only'),
  ('trg_rental_inventory_movement_items_draft_only'),
  ('trg_inventory_conversions_domains'),
  ('trg_inventory_conversions_draft_only'),
  ('trg_product_stock_reservations_lifecycle'),
  ('trg_rental_stock_reservations_lifecycle')
) expected(name)
JOIN pg_trigger actual ON actual.tgname = expected.name AND NOT actual.tgisinternal;

INSERT INTO p5_structure_issues
SELECT 'legacy_evidence', expected.name, 'P5 migration evidence table is missing'
FROM (VALUES
  ('p5_legacy_booking_policies'), ('p5_legacy_zone_blocks'),
  ('p5_legacy_campground_closures'), ('p5_legacy_min_stocks'),
  ('p5_legacy_movements'), ('p5_legacy_movement_items'),
  ('p5_policy_source'), ('p5_zone_block_source'), ('p5_closure_source'),
  ('p5_min_stock_source'), ('p5_movement_source'),
  ('p5_location_resolution'), ('p5_variant_resolution')
) expected(name)
LEFT JOIN information_schema.tables actual
  ON actual.table_schema = 'migration' AND actual.table_name = expected.name
WHERE actual.table_name IS NULL;

INSERT INTO p5_structure_issues
SELECT 'p6_scope', actual.table_name, 'P6-only target exists during P5'
FROM information_schema.tables actual
WHERE actual.table_schema = 'public'
  AND actual.table_name IN (
    'review_photos', 'legacy_reviews', 'legacy_review_photos',
    'article_tags', 'review_replies'
  );

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', coalesce(jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name), '[]'::jsonb)
))
FROM p5_structure_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p5_structure_issues) THEN
    RAISE EXCEPTION 'P5 structure validation failed with % issue(s)',
      (SELECT count(*) FROM p5_structure_issues);
  END IF;
END $$;
