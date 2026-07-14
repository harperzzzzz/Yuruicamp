\set ON_ERROR_STOP on

CREATE TEMP TABLE p2_structure_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p2_structure_issues
SELECT 'required_relation', expected.name, 'missing P2 table or view'
FROM (VALUES
  ('equipment_items'), ('equipment_images'), ('equipment_tags'),
  ('equipment_interest_tags'), ('equipment_specifications'), ('products'),
  ('product_variants'), ('environment_tags'), ('facility_tags'),
  ('campground_environment_tags'), ('campground_facility_tags'),
  ('inventory_stocks'), ('product_stock_summary')
) expected(name)
LEFT JOIN information_schema.tables actual
  ON actual.table_schema = 'public' AND actual.table_name = expected.name
WHERE actual.table_name IS NULL;

INSERT INTO p2_structure_issues
SELECT 'required_constraint', expected.name, 'missing or wrong constraint type'
FROM (VALUES
  ('pk_equipment_items', 'p'),
  ('fk_equipment_items_category_id', 'f'), ('fk_equipment_items_brand_id', 'f'),
  ('pk_equipment_images', 'p'), ('fk_equipment_images_item_id', 'f'),
  ('ck_equipment_images_sort_order', 'c'), ('ck_equipment_images_value', 'c'),
  ('pk_equipment_tags', 'p'), ('fk_equipment_tags_item_id', 'f'),
  ('ck_equipment_tags_value', 'c'),
  ('pk_equipment_interest_tags', 'p'), ('fk_equipment_interest_tags_item_id', 'f'),
  ('ck_equipment_interest_tags_value', 'c'),
  ('pk_equipment_specifications', 'p'), ('fk_equipment_specifications_item_id', 'f'),
  ('ck_equipment_specifications_value', 'c'),
  ('pk_products', 'p'), ('fk_products_item_id', 'f'), ('uq_products_item_id', 'u'),
  ('ck_products_price', 'c'), ('ck_products_status', 'c'),
  ('pk_product_variants', 'p'), ('fk_product_variants_product_id', 'f'),
  ('uq_product_variants_sku', 'u'), ('uq_product_variants_product_id_id', 'u'),
  ('ck_product_variants_price', 'c'), ('ck_product_variants_status', 'c'),
  ('pk_environment_tags', 'p'), ('uq_environment_tags_code', 'u'),
  ('uq_environment_tags_label', 'u'), ('ck_environment_tags_sort_order', 'c'),
  ('pk_facility_tags', 'p'), ('uq_facility_tags_code', 'u'),
  ('uq_facility_tags_label', 'u'), ('ck_facility_tags_sort_order', 'c'),
  ('pk_campground_environment_tags', 'p'),
  ('fk_campground_environment_tags_campground_id', 'f'),
  ('fk_campground_environment_tags_tag_id', 'f'),
  ('pk_campground_facility_tags', 'p'),
  ('fk_campground_facility_tags_campground_id', 'f'),
  ('fk_campground_facility_tags_tag_id', 'f'),
  ('pk_inventory_stocks', 'p'), ('fk_inventory_stocks_location_id', 'f'),
  ('fk_inventory_stocks_variant_id', 'f'), ('ck_inventory_stocks_on_hand', 'c')
) expected(name, type)
LEFT JOIN pg_constraint actual
  ON actual.conname = expected.name AND actual.contype::text = expected.type
WHERE actual.oid IS NULL;

INSERT INTO p2_structure_issues
SELECT 'required_index', expected.name, 'missing or invalid P2 index'
FROM (VALUES
  ('idx_equipment_items_category_active'), ('idx_equipment_items_brand'),
  ('idx_equipment_images_sort_order'), ('idx_equipment_tags_tag'),
  ('idx_equipment_interest_tags_tag'), ('idx_equipment_specifications_spec_key'),
  ('idx_products_status'), ('idx_product_variants_product_status'),
  ('idx_environment_tags_active_sort'), ('idx_facility_tags_active_sort'),
  ('idx_campground_environment_tags_tag'), ('idx_campground_facility_tags_tag'),
  ('idx_inventory_stocks_variant')
) expected(name)
LEFT JOIN pg_class index_class ON index_class.relname = expected.name
LEFT JOIN pg_index index_data ON index_data.indexrelid = index_class.oid
WHERE index_class.oid IS NULL OR NOT index_data.indisvalid;

WITH p2_tables AS (
  SELECT relation.oid
  FROM pg_class relation
  JOIN pg_namespace namespace ON namespace.oid = relation.relnamespace
  WHERE namespace.nspname = 'public'
    AND relation.relname IN (
      'equipment_items', 'equipment_images', 'equipment_tags',
      'equipment_interest_tags', 'equipment_specifications', 'products',
      'product_variants', 'campground_environment_tags',
      'campground_facility_tags', 'inventory_stocks'
    )
), foreign_keys AS (
  SELECT constraint_data.conname, constraint_data.conrelid, constraint_data.conkey
  FROM pg_constraint constraint_data
  JOIN p2_tables p2_table ON p2_table.oid = constraint_data.conrelid
  WHERE constraint_data.contype = 'f'
)
INSERT INTO p2_structure_issues
SELECT 'foreign_key_index', foreign_key.conname, 'referencing columns lack a usable index'
FROM foreign_keys foreign_key
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_index index_data
  WHERE index_data.indrelid = foreign_key.conrelid
    AND index_data.indisvalid
    AND foreign_key.conkey <@ index_data.indkey::smallint[]
);

INSERT INTO p2_structure_issues
SELECT 'legacy_column', table_name || '.' || column_name,
       'P2 legacy JSONB/cache/display column still exists'
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (table_name, column_name) IN (
    ('products', 'rental_id'), ('products', 'rental_enabled'),
    ('products', 'name'), ('products', 'category'), ('products', 'brand'),
    ('products', 'interest_tags'), ('products', 'image'), ('products', 'images'),
    ('products', 'description'), ('products', 'specifications'), ('products', 'tags'),
    ('products', 'total_stock'), ('product_variants', 'label'),
    ('product_variants', 'branch_stock'), ('campgrounds', 'environment_tags'),
    ('campgrounds', 'facility_tags'), ('inventory_stocks', 'reserved_quantity')
  );

INSERT INTO p2_structure_issues
SELECT 'summary_column', expected.name, 'missing or wrong product_stock_summary type'
FROM (VALUES
  ('product_id', 'character varying'),
  ('total_on_hand', 'bigint'),
  ('total_reserved', 'bigint'),
  ('total_available', 'bigint')
) expected(name, type)
LEFT JOIN information_schema.columns actual
  ON actual.table_schema = 'public'
 AND actual.table_name = 'product_stock_summary'
 AND actual.column_name = expected.name
WHERE actual.column_name IS NULL OR actual.data_type <> expected.type;

INSERT INTO p2_structure_issues
SELECT 'p3_scope', forbidden.name, 'P3 target object exists before P2 completion'
FROM (VALUES
  ('rental_sku_variants'), ('campground_rental_locations'),
  ('rental_sku_variant_min_stocks'), ('rental_stock_reservations'),
  ('rental_listing_view')
) forbidden(name)
JOIN information_schema.tables actual
  ON actual.table_schema = 'public' AND actual.table_name = forbidden.name;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', COALESCE(jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name), '[]'::jsonb)
))
FROM p2_structure_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p2_structure_issues) THEN
    RAISE EXCEPTION 'P2 structure validation failed with % issue(s)',
      (SELECT count(*) FROM p2_structure_issues);
  END IF;
END $$;
