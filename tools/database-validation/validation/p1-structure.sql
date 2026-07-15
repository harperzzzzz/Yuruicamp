\set ON_ERROR_STOP on

CREATE TEMP TABLE p1_structure_issues (
  check_name TEXT NOT NULL,
  object_name TEXT NOT NULL,
  reason TEXT NOT NULL
);

INSERT INTO p1_structure_issues
SELECT 'forbidden_column', 'customers.avatar', 'legacy customer avatar column must not exist'
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'customers'
  AND column_name = 'avatar';

INSERT INTO p1_structure_issues
SELECT 'forbidden_column', 'customers.total_spent',
       'customer spending must be derived from customer_spending_summary'
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'customers'
  AND column_name = 'total_spent';

INSERT INTO p1_structure_issues
SELECT 'forbidden_column', 'customers.' || column_name,
       'normalized customer relations are the only authoritative source'
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'customers'
  AND column_name IN ('preferences', 'shipping_address', 'tags');

INSERT INTO p1_structure_issues
SELECT 'required_column', 'customers.deleted_at', 'soft-delete timestamp column is missing'
WHERE NOT EXISTS (
  SELECT 1
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'customers'
    AND column_name = 'deleted_at'
    AND data_type = 'timestamp with time zone'
    AND is_nullable = 'YES'
);

INSERT INTO p1_structure_issues
SELECT 'required_default', 'customers.id', 'customer id must default to a 32-character UUID'
WHERE NOT EXISTS (
  SELECT 1
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'customers'
    AND column_name = 'id'
    AND column_default = 'replace((gen_random_uuid())::text, ''-''::text, ''''::text)'
);

INSERT INTO p1_structure_issues
SELECT 'required_object', expected.name, 'missing customer soft-delete database object'
FROM (VALUES
  ('active_customers', 'v'),
  ('soft_delete_customer', 'f'),
  ('reject_customer_hard_delete', 'f'),
  ('trg_customers_prevent_hard_delete', 't')
) expected(name, kind)
WHERE CASE expected.kind
  WHEN 'v' THEN NOT EXISTS (
    SELECT 1 FROM information_schema.views
    WHERE table_schema = 'public' AND table_name = expected.name
  )
  WHEN 'f' THEN NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = expected.name
  )
  WHEN 't' THEN NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgname = expected.name AND NOT tgisinternal
  )
END;

INSERT INTO p1_structure_issues
SELECT 'required_table', expected.name, 'missing P1 table'
FROM (VALUES
  ('admin_users'), ('customers'), ('customer_shipping_addresses'),
  ('preference_options'), ('customer_preferences'), ('customer_tags'),
  ('customer_tag_assignments'), ('brands'), ('product_categories'),
  ('campgrounds'), ('campground_zones'), ('branches'), ('branch_features'),
  ('inventory_locations')
) expected(name)
LEFT JOIN information_schema.tables actual
  ON actual.table_schema = 'public' AND actual.table_name = expected.name
WHERE actual.table_name IS NULL;

INSERT INTO p1_structure_issues
SELECT 'required_constraint', expected.name, 'missing or wrong constraint type'
FROM (VALUES
  ('pk_admin_users', 'p'), ('uq_admin_users_email', 'u'), ('ck_admin_users_role', 'c'),
  ('pk_customers', 'p'), ('uq_customers_email', 'u'), ('ck_customers_points', 'c'),
  ('pk_customer_shipping_addresses', 'p'), ('fk_customer_shipping_addresses_customer_id', 'f'),
  ('pk_preference_options', 'p'), ('uq_preference_options_type_code', 'u'),
  ('uq_preference_options_type_label', 'u'), ('ck_preference_options_type', 'c'),
  ('pk_customer_preferences', 'p'), ('fk_customer_preferences_customer_id', 'f'),
  ('fk_customer_preferences_preference_id', 'f'), ('pk_customer_tags', 'p'),
  ('uq_customer_tags_name', 'u'), ('pk_customer_tag_assignments', 'p'),
  ('fk_customer_tag_assignments_customer_id', 'f'), ('fk_customer_tag_assignments_tag_id', 'f'),
  ('pk_brands', 'p'), ('ck_brands_name', 'c'), ('pk_product_categories', 'p'),
  ('ck_product_categories_code', 'c'),
  ('ck_product_categories_name', 'c'),
  ('pk_campgrounds', 'p'), ('pk_campground_zones', 'p'),
  ('fk_campground_zones_campground_id', 'f'), ('uq_campground_zones_id_campground_id', 'u'),
  ('ck_campground_zones_capacity', 'c'), ('ck_campground_zones_sites', 'c'),
  ('ck_campground_zones_prices', 'c'), ('pk_branches', 'p'), ('uq_branches_code', 'u'),
  ('pk_branch_features', 'p'), ('fk_branch_features_branch_id', 'f'),
  ('pk_inventory_locations', 'p'), ('fk_inventory_locations_branch_id', 'f'),
  ('uq_inventory_locations_code', 'u'), ('uq_inventory_locations_id_inventory_domain', 'u'),
  ('ck_inventory_locations_domain', 'c'), ('ck_inventory_locations_type', 'c'),
  ('ck_inventory_locations_branch_type', 'c'), ('ck_inventory_locations_domain_type', 'c'),
  ('fk_movements_employee_id', 'f'), ('fk_zone_blocks_created_by', 'f'),
  ('fk_campground_closures_created_by', 'f')
) expected(name, type)
LEFT JOIN pg_constraint actual
  ON actual.conname = expected.name AND actual.contype::text = expected.type
WHERE actual.oid IS NULL;

INSERT INTO p1_structure_issues
SELECT 'required_index', expected.name, 'missing or invalid P1 index'
FROM (VALUES
  ('idx_admin_users_role_active'), ('idx_customers_auth_provider'), ('idx_customers_active_email'),
  ('idx_customer_shipping_addresses_customer'), ('idx_customer_shipping_addresses_one_default'),
  ('idx_preference_options_type_active_sort'), ('idx_customer_preferences_preference'),
  ('idx_customer_tags_active_sort'), ('idx_customer_tag_assignments_tag'),
  ('uq_brands_name'), ('uq_product_categories_code'), ('uq_product_categories_name'),
  ('idx_campgrounds_region_active'), ('idx_campground_zones_campground_active'),
  ('idx_branches_active_code'), ('idx_branch_features_feature'),
  ('idx_inventory_locations_domain_type_active'), ('idx_inventory_locations_branch'),
  ('idx_movements_employee_id'), ('idx_zone_blocks_created_by'),
  ('idx_zone_blocks_campground_id'), ('idx_zone_blocks_zone_id'),
  ('idx_campground_closures_created_by'), ('idx_campground_closures_campground_id')
) expected(name)
LEFT JOIN pg_class index_class ON index_class.relname = expected.name
LEFT JOIN pg_index index_data ON index_data.indexrelid = index_class.oid
WHERE index_class.oid IS NULL OR NOT index_data.indisvalid;

WITH p1_tables AS (
  SELECT c.oid, c.relname
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN (
      'customer_shipping_addresses', 'customer_preferences', 'customer_tag_assignments',
      'campground_zones', 'branch_features', 'inventory_locations', 'movements',
      'zone_blocks', 'campground_closures'
    )
), foreign_keys AS (
  SELECT c.oid, c.conname, c.conrelid, c.conkey
  FROM pg_constraint c
  JOIN p1_tables t ON t.oid = c.conrelid
  WHERE c.contype = 'f'
)
INSERT INTO p1_structure_issues
SELECT 'foreign_key_index', foreign_key.conname, 'referencing columns lack a usable index'
FROM foreign_keys foreign_key
WHERE NOT EXISTS (
  SELECT 1
  FROM pg_index index_data
  WHERE index_data.indrelid = foreign_key.conrelid
    AND index_data.indisvalid
    AND foreign_key.conkey <@ index_data.indkey::smallint[]
);

INSERT INTO p1_structure_issues
SELECT 'p2_scope', forbidden.name, 'P2 object exists before P1 completion'
FROM (VALUES
  ('equipment_items'), ('equipment_images'), ('equipment_tags'),
  ('equipment_interest_tags'), ('equipment_specifications'),
  ('inventory_stocks'), ('product_stock_summary')
) forbidden(name)
JOIN information_schema.tables actual
  ON actual.table_schema = 'public' AND actual.table_name = forbidden.name;

SELECT jsonb_pretty(jsonb_build_object(
  'issueCount', count(*),
  'issues', COALESCE(jsonb_agg(jsonb_build_object(
    'check', check_name, 'object', object_name, 'reason', reason
  ) ORDER BY check_name, object_name), '[]'::jsonb)
))
FROM p1_structure_issues;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM p1_structure_issues) THEN
    RAISE EXCEPTION 'P1 structure validation failed with % issue(s)',
      (SELECT count(*) FROM p1_structure_issues);
  END IF;
END $$;
