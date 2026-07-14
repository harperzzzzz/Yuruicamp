\set ON_ERROR_STOP on

CREATE TEMP TABLE p3_structure_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p3_structure_issues
SELECT 'required_relation', expected.name, 'missing P3 table or view'
FROM (VALUES
  ('rental_skus'), ('rental_sku_variants'),
  ('campground_rental_locations'), ('rental_sku_variant_stocks'),
  ('rental_listings'), ('rental_listing_view')
) expected(name)
LEFT JOIN information_schema.tables actual
  ON actual.table_schema = 'public' AND actual.table_name = expected.name
WHERE actual.table_name IS NULL;

INSERT INTO p3_structure_issues
SELECT 'required_constraint', expected.name, 'missing or wrong constraint type'
FROM (VALUES
  ('pk_rental_skus', 'p'), ('fk_rental_skus_item_id', 'f'),
  ('uq_rental_skus_item_id', 'u'), ('ck_rental_skus_status', 'c'),
  ('pk_rental_sku_variants', 'p'), ('fk_rental_sku_variants_rental_sku_id', 'f'),
  ('uq_rental_sku_variants_sku', 'u'),
  ('uq_rental_sku_variants_rental_sku_id_id', 'u'),
  ('ck_rental_sku_variants_status', 'c'),
  ('pk_campground_rental_locations', 'p'),
  ('fk_campground_rental_locations_campground_id', 'f'),
  ('fk_campground_rental_locations_location_id', 'f'),
  ('uq_campground_rental_locations_location_id', 'u'),
  ('pk_rental_sku_variant_stocks', 'p'),
  ('fk_rental_sku_variant_stocks_location_id', 'f'),
  ('fk_rental_sku_variant_stocks_rental_sku_variant_id', 'f'),
  ('ck_rental_sku_variant_stocks_on_hand', 'c'),
  ('pk_rental_listings', 'p'), ('fk_rental_listings_campground_id', 'f'),
  ('fk_rental_listings_campground_location', 'f'),
  ('fk_rental_listings_rental_sku_variant_id', 'f'),
  ('uq_rental_listings_campground_id_rental_sku_variant_id', 'u'),
  ('ck_rental_listings_prices', 'c')
) expected(name, type)
LEFT JOIN pg_constraint actual
  ON actual.conname = expected.name AND actual.contype::text = expected.type
WHERE actual.oid IS NULL;

INSERT INTO p3_structure_issues
SELECT 'required_index', expected.name, 'missing or invalid P3 index'
FROM (VALUES
  ('idx_rental_skus_status'), ('idx_rental_sku_variants_sku_status'),
  ('idx_rental_sku_variant_stocks_variant'),
  ('idx_rental_listings_variant_active')
) expected(name)
LEFT JOIN pg_class index_class ON index_class.relname = expected.name
LEFT JOIN pg_index index_data ON index_data.indexrelid = index_class.oid
WHERE index_class.oid IS NULL OR NOT index_data.indisvalid;

WITH p3_tables AS (
  SELECT relation.oid
  FROM pg_class relation
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname IN (
      'rental_skus', 'rental_sku_variants', 'campground_rental_locations',
      'rental_sku_variant_stocks', 'rental_listings'
    )
), foreign_keys AS (
  SELECT constraint_data.conname, constraint_data.conrelid, constraint_data.conkey
  FROM pg_constraint constraint_data
  JOIN p3_tables p3_table ON p3_table.oid = constraint_data.conrelid
  WHERE constraint_data.contype = 'f'
)
INSERT INTO p3_structure_issues
SELECT 'foreign_key_index', foreign_key.conname, 'referencing columns lack a usable index'
FROM foreign_keys foreign_key
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_index index_data
  WHERE index_data.indrelid = foreign_key.conrelid
    AND index_data.indisvalid
    AND foreign_key.conkey <@ index_data.indkey::smallint[]
);

INSERT INTO p3_structure_issues
SELECT 'legacy_column', table_name || '.' || column_name,
       'P3 legacy product/location/display/derived column still exists'
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (table_name, column_name) IN (
    ('rental_skus', 'product_id'), ('rental_skus', 'image'),
    ('rental_skus', 'name'), ('rental_skus', 'category'), ('rental_skus', 'brand'),
    ('rental_sku_variant_stocks', 'id'),
    ('rental_sku_variant_stocks', 'rental_sku_id'),
    ('rental_sku_variant_stocks', 'variant_id'),
    ('rental_sku_variant_stocks', 'campground_id'),
    ('rental_sku_variant_stocks', 'quantity'),
    ('rental_sku_variant_stocks', 'reserved_quantity'),
    ('rental_listings', 'rental_sku_id'), ('rental_listings', 'product_id'),
    ('rental_listings', 'variant_id'), ('rental_listings', 'sku'),
    ('rental_listings', 'name'), ('rental_listings', 'color'),
    ('rental_listings', 'size'), ('rental_listings', 'spec_label'),
    ('rental_listings', 'image_url'), ('rental_listings', 'terrain_tag'),
    ('rental_listings', 'stock'), ('rental_listings', 'location_id')
  );

INSERT INTO p3_structure_issues
SELECT 'required_trigger', expected.name, 'missing or disabled P3 location-type trigger'
FROM (VALUES
  ('trg_campground_rental_locations_type'),
  ('trg_inventory_locations_protect_rental_mapping')
) expected(name)
LEFT JOIN pg_trigger trigger_data
  ON trigger_data.tgname = expected.name AND NOT trigger_data.tgisinternal
WHERE trigger_data.oid IS NULL OR trigger_data.tgenabled = 'D';

INSERT INTO p3_structure_issues
SELECT 'view_column', expected.name, 'missing or wrong rental_listing_view type'
FROM (VALUES
  ('id', 'character varying'), ('campground_id', 'character varying'),
  ('rental_sku_variant_id', 'character varying'), ('location_id', 'character varying'),
  ('price_per_day_weekday', 'numeric'), ('price_per_day_holiday', 'numeric'),
  ('discount', 'numeric'), ('stock', 'integer')
) expected(name, type)
LEFT JOIN information_schema.columns actual
  ON actual.table_schema = 'public'
 AND actual.table_name = 'rental_listing_view'
 AND actual.column_name = expected.name
WHERE actual.column_name IS NULL OR actual.data_type <> expected.type;

INSERT INTO p3_structure_issues
SELECT 'legacy_audit', expected.name, 'P3 legacy audit table is missing from migration schema'
FROM (VALUES
  ('p3_legacy_rental_sku_variant_stocks'),
  ('p3_legacy_rental_listings'),
  ('p3_rental_sku_source'), ('p3_listing_source'),
  ('p3_rental_variant_map'), ('p3_rental_min_stock_source')
) expected(name)
LEFT JOIN information_schema.tables actual
  ON actual.table_schema = 'migration' AND actual.table_name = expected.name
WHERE actual.table_name IS NULL;

INSERT INTO p3_structure_issues
SELECT 'p4_scope', forbidden.name, 'P4 target object exists before P3 completion'
FROM (VALUES
  ('calendar_dates'), ('coupon_usage_adjustments'),
  ('product_stock_reservations'), ('rental_stock_reservations'),
  ('order_status_history'), ('booking_status_history')
) forbidden(name)
JOIN information_schema.tables actual
  ON actual.table_schema = 'public' AND actual.table_name = forbidden.name;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', COALESCE(jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name), '[]'::jsonb)
))
FROM p3_structure_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p3_structure_issues) THEN
    RAISE EXCEPTION 'P3 structure validation failed with % issue(s)',
      (SELECT count(*) FROM p3_structure_issues);
  END IF;
END $$;
